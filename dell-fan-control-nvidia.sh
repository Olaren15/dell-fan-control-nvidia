#!/bin/bash

# Define global functions
# This function applies Dell's default dynamic fan control profile
function apply_automatic_fan_control () {
  # Use ipmitool to send the raw command to set fan control to Dell default
  ipmitool -I $IDRAC_CONNECTION_STRING raw 0x30 0x30 0x01 0x01 > /dev/null
  FAN_CONTROL_CURRENT_STATE=$FAN_CONTROL_STATE_AUTOMATIC
}

# This function applies a user-specified static fan control profile
function apply_manual_fan_control () {
  # Use ipmitool to send the raw command to set fan control to user-specified value
  ipmitool -I $IDRAC_CONNECTION_STRING raw 0x30 0x30 0x01 0x00 > /dev/null
  FAN_CONTROL_CURRENT_STATE=$FAN_CONTROL_STATE_MANUAL
}

function apply_fan_speed () {
    # Convert the decimal value to hex
    local HEXADECIMAL_FAN_SPEED=$(printf '0x%02x' $1)

    ipmitool -I $IDRAC_CONNECTION_STRING raw 0x30 0x30 0x02 0xff $HEXADECIMAL_FAN_SPEED > /dev/null
    FAN_CONTROL_MANUAL_PERCENTAGE=$1
    STEPS_SINCE_LAST_FAN_CHANGED=0
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

# Trap the signals for script exit and run gracefull_exit function
trap 'gracefull_exit' SIGQUIT SIGKILL SIGTERM EXIT

# Your values here
IDRAC_CONNECTION_STRING="lanplus -H <YOUR IDRAC IP HERE> -U <YOUR USERNAME HERE> -P <YOUR PASSWORD HERE>"

FAN_CONTROL_STATE_MANUAL="manual"
FAN_CONTROL_STATE_AUTOMATIC="automatic"

FAN_CONTROL_CURRENT_STATE=$FAN_CONTROL_STATE_AUTOMATIC
FAN_CONTROL_MANUAL_PERCENTAGE=0

STEPS_SINCE_LAST_FAN_CHANGED=0

apply_automatic_fan_control

while true; do
  sleep 2 &
  SLEEP_PROCESS_PID=$!

  retrieve_temperatures

  if (($GPU_TEMP >= 65)); then
      if [[ "$FAN_CONTROL_STATE_AUTOMATIC" == "$FAN_CONTROL_CURRENT_STATE" ]]; then
        # If we are above the minimum treshold and the control isn't already manual, change it.
        echo "GPU temperature is getting high. Enabling manual fan control."
        apply_manual_fan_control
      fi

      if [[ $GPU_TEMP -ge 90 && $FAN_CONTROL_MANUAL_PERCENTAGE != 80 ]]; then
        echo "GPU temperature is critical (>= 90C). Setting fans to 80%."
        apply_fan_speed 80
      elif [[ $GPU_TEMP -ge 85 && $GPU_TEMP -lt 90 && ($FAN_CONTROL_MANUAL_PERCENTAGE -lt 65 || ($FAN_CONTROL_MANUAL_PERCENTAGE -gt 65 && $STEPS_SINCE_LAST_FAN_CHANGED -ge 10)) ]]; then
        # Allow going from a lower fan % to a higher one, but don't lower the fan % for a certain time (10 steps of 2 seconds or 20 seconds) to minimize the fans spnning up and donw rapidly
        echo "GPU temperature is reaching critical (>= 85C). Setting fans to 65%."
        apply_fan_speed 65
      elif [[ $GPU_TEMP -ge 75 && $GPU_TEMP -lt 85 && ($FAN_CONTROL_MANUAL_PERCENTAGE -lt 50 || ($FAN_CONTROL_MANUAL_PERCENTAGE -gt 50 && $STEPS_SINCE_LAST_FAN_CHANGED -ge 10)) ]]; then
        # Allow going from a lower fan % to a higher one, but don't lower the fan % for a certain time (10 steps of 2 seconds or 20 seconds) to minimize the fans spnning up and donw rapidly
        echo "GPU temperature is very high (>= 75C). Setting fans to 50%."
        apply_fan_speed 50
      elif [[ $GPU_TEMP -ge 70 && $GPU_TEMP -lt 75 && ($FAN_CONTROL_MANUAL_PERCENTAGE -lt 40 || ($FAN_CONTROL_MANUAL_PERCENTAGE -gt 40 && $STEPS_SINCE_LAST_FAN_CHANGED -ge 10)) ]]; then
        # Allow going from a lower fan % to a higher one, but don't lower the fan % for a certain time (10 steps of 2 seconds or 20 seconds) to minimize the fans spnning up and donw rapidly
        echo "GPU temperature is high (>= 75C). Setting fans to 40%."
        apply_fan_speed 40
      elif [[ $GPU_TEMP -lt 70 && ($FAN_CONTROL_MANUAL_PERCENTAGE -lt 30 || ($FAN_CONTROL_MANUAL_PERCENTAGE -gt 30 && $STEPS_SINCE_LAST_FAN_CHANGED -ge 10)) ]]; then
        # Allow going from a lower fan % to a higher one, but don't lower the fan % for a certain time (10 steps of 2 seconds or 20 seconds) to minimize the fans spnning up and donw rapidly
        echo "GPU temperature is getting warm (>= 65C). Setting fans to 30%."
        apply_fan_speed 30
      fi

  elif [[ "$FAN_CONTROL_STATE_MANUAL" == "$FAN_CONTROL_CURRENT_STATE" ]]; then
    # Reset automatic fan control if temperature is below 65 degrees and we are currently in manual mode 
    echo "GPU temperature is calming down. Returning to automatic fan control."
    apply_automatic_fan_control
    FAN_CONTROL_MANUAL_PERCENTAGE=0
  fi

  STEPS_SINCE_LAST_FAN_CHANGED=$(($STEPS_SINCE_LAST_FAN_CHANGED + 1))
  wait $SLEEP_PROCESS_PID
done
