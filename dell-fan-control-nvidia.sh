#!/bin/bash

# Define global functions
# This function applies Dell's default dynamic fan control profile
function apply_automatic_fan_control () {
  # Use ipmitool to send the raw command to set fan control to Dell default
  ipmitool -I $IDRAC_CONNECTION_STRING raw 0x30 0x30 0x01 0x01 > /dev/null
  FAN_CONTROL_CURRENT_STATE=$FAN_CONTROL_STATE_AUTOMATIC
  echo "Fan control set to automatic."
}

# This function applies a user-specified static fan control profile
function apply_manual_fan_control () {
  # Use ipmitool to send the raw command to set fan control to user-specified value
  ipmitool -I $IDRAC_CONNECTION_STRING raw 0x30 0x30 0x01 0x00 > /dev/null
  FAN_CONTROL_CURRENT_STATE=$FAN_CONTROL_STATE_MANUAL
  echo "Fan control set to manual."
}

function apply_fan_speed () {
    # Convert the decimal value to hex
    local HEXADECIMAL_FAN_SPEED=$(printf '0x%02x' $1)

    ipmitool -I $IDRAC_CONNECTION_STRING raw 0x30 0x30 0x02 0xff $HEXADECIMAL_FAN_SPEED > /dev/null
    FAN_CONTROL_MANUAL_PERCENTAGE=$1
    STEPS_SINCE_LAST_FAN_CHANGED=0
    echo "Fan speed set to $1% ($HEXADECIMAL_FAN_SPEED)."
}

# Retrieve temperature sensors data using nvidia-smi (Edited for multi-gpu compatibility)
function retrieve_temperatures () {
  GPU_TEMP=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader | awk 'BEGIN{max=0} {if($1>max) max=$1} END{print max}')
  echo "Current Highest GPU Temp: $GPU_TEMP °C"
}

# Prepare traps in case of script exit
function gracefull_exit () {
  apply_automatic_fan_control
  echo "Script stopped, automatic fan speed restored for safety."
  exit 0
}

function emergency_shutdown () {
  echo "Emergency termination triggered! GPU temperature (${GPU_TEMP}°C) exceeds the threshold (${EMRG_TERM_TEMP}°C)."
  echo "Shutting down the system immediately!"
  shutdown -h now
}

# Trap the signals for script exit and run gracefull_exit function
trap 'gracefull_exit' SIGQUIT SIGKILL SIGTERM EXIT

# --- User Configuration ---
IDRAC_CONNECTION_STRING="lanplus -H <YOUR IDRAC IP HERE> -U <YOUR USERNAME HERE> -P <YOUR PASSWORD HERE>"

# Fan Control States (do not modify if you don't know what these are)
FAN_CONTROL_STATE_MANUAL="manual"
FAN_CONTROL_STATE_AUTOMATIC="automatic"
FAN_CONTROL_CURRENT_STATE=$FAN_CONTROL_STATE_AUTOMATIC
FAN_CONTROL_MANUAL_PERCENTAGE=0

# Linear Fan Speed Algorithm Variables
MIN_TEMP=65        # Temperature in Celsius to start increasing fan speed
MAX_TEMP=90        # Temperature in Celsius at which fan speed reaches maximum
MIN_FAN=20         # Minimum fan speed percentage
MAX_FAN=100         # Maximum fan speed percentage

# Emegerency Termination

EMRG_TERM_STATE="enabled" # or "disabled". Enabled by default to prevent hw dmg
EMRG_TERM_TEMP=100 #in deg celsius, when reached, system will shut down immediately if termination is enabled

# --- End of User Configuration ---

# Non-linear Fan Speed Algorithm
while true; do
  sleep 2 &
  SLEEP_PROCESS_PID=$!

  retrieve_temperatures

  if [[ "$EMRG_TERM_STATE" == "enabled" && $GPU_TEMP -ge $EMRG_TERM_TEMP ]]; then
    emergency_shutdown
  fi

  if (($GPU_TEMP >= $MIN_TEMP)); then
      if [[ "$FAN_CONTROL_STATE_AUTOMATIC" == "$FAN_CONTROL_CURRENT_STATE" ]]; then
        echo "GPU temperature is getting high. Enabling manual fan control."
        apply_manual_fan_control
      fi

      # Non-Linear Fan Speed Algorithm
      if (($GPU_TEMP <= $MAX_TEMP)); then
          # Calculate fan speed using a quadratic formula
          TEMP_RATIO=$(echo "scale=4; ($GPU_TEMP - $MIN_TEMP) / ($MAX_TEMP - $MIN_TEMP)" | bc)
          FAN_SPEED=$(echo "$MIN_FAN + ($MAX_FAN - $MIN_FAN) * ($TEMP_RATIO ^ 2)" | bc | awk '{printf("%d\n", $1 + 0.5)}')

          # Ensure fan speed is within bounds
          if (($FAN_SPEED < $MIN_FAN)); then
              FAN_SPEED=$MIN_FAN
          elif (($FAN_SPEED > $MAX_FAN)); then
              FAN_SPEED=$MAX_FAN
          fi
      else
          # If temperature exceeds MAX_TEMP, set fan to MAX_FAN
          FAN_SPEED=$MAX_FAN
      fi

      # Apply fan speed only if it's different from the current manual percentage
      if [[ "$FAN_CONTROL_MANUAL_PERCENTAGE" != "$FAN_SPEED" ]]; then
          echo "Setting fan speed to ${FAN_SPEED}% based on non-linear algorithm."
          apply_fan_speed $FAN_SPEED
      fi

  elif [[ "$FAN_CONTROL_STATE_MANUAL" == "$FAN_CONTROL_CURRENT_STATE" ]]; then
    # Reset automatic fan control if temperature is below MIN_TEMP and we are currently in manual mode
    echo "GPU temperature is calming down. Returning to automatic fan control."
    apply_automatic_fan_control
    FAN_CONTROL_MANUAL_PERCENTAGE=0
  fi

  wait $SLEEP_PROCESS_PID
done
