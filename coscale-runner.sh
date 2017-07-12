#!/bin/sh

AGENT_BIN="coscale-agent"
API_CONFIG_FILE="etc/api.conf"
CONFIG_FILE="etc/agent.conf"
UPDATE_DIR="update"
PLUGINS_DIR="plugins"
UPDATE_LOG="update.log"
UPDATE_STATUS="update.status"

AGENT_CMD="./$AGENT_BIN --api-config=$API_CONFIG_FILE --config=$CONFIG_FILE --update-dir=$UPDATE_DIR --plugins-dir=$PLUGINS_DIR"

ST_RESTART=1
ST_INIT_FAILED=2
ST_SERVER_DISABLED=3
ST_DO_UPDATE=66
ST_UPDATE_SUCCESS=67
ST_FATAL=77

do_update() {
	STATUS=${UPDATE_DIR}/${UPDATE_STATUS}
	LOG=${UPDATE_DIR}/${UPDATE_LOG}
	EXIT_CODE=-1

	if [ ! -e $STATUS ]; then
		echo "START" > $STATUS
	fi

	while [ "$EXIT_CODE" == "-1" ]; do
		case "`cat $STATUS`" in
			'START')
				if [ ! -e ${UPDATE_DIR}/$AGENT_BIN ]; then
					echo "Could not find new agent in update dir." > $LOG
					$AGENT_CMD --update-failed="$LOG"
					EXIT_CODE=1
				else
					echo "EXISTS" > $STATUS
				fi
			;;
			'EXISTS')
				# Put the new agent into place
				mv $AGENT_BIN ${UPDATE_DIR}/${AGENT_BIN}.bak
				cp ${UPDATE_DIR}/$AGENT_BIN $AGENT_BIN
				chmod +x $AGENT_BIN
				echo "MOVED" > $STATUS
			;;
			'MOVED')
				# Do the first run of the new agent
				echo "Performing the agents first run."
				$AGENT_CMD --first-run > $LOG 2>&1
				RET=$?

				if [ "$RET" == "$ST_UPDATE_SUCCESS" ]; then
					echo "SUCCESS" > $STATUS
				else
					echo "FAILED" > $STATUS
				fi
			;;
			'SUCCESS')
				# Report successful update to the updated agent
				$AGENT_CMD --update-success="$LOG" 2>&1
				EXIT_CODE=0
			;;
			'FAILED')
				# Move the old agent back into place
				rm $AGENT_BIN
				mv ${UPDATE_DIR}/${AGENT_BIN}.bak $AGENT_BIN
				echo "REVERTED" > $STATUS
			;;
			'REVERTED')
				# Report unsuccesful update to the old agent
				$AGENT_CMD --update-failed="$LOG"
				EXIT_CODE=1
			;;
		esac
	done

	rm $STATUS
	return $EXIT_CODE
}

# Work from the directory where the wrapper script is located.
cd `dirname $0`

# Create the update and plugin directories if they don't exist.
mkdir -p $UPDATE_DIR
mkdir -p $PLUGINS_DIR

# If the wrapper was stopped in the middle of an update, resume the update.
if [ -e ${UPDATE_DIR}/${UPDATE_STATUS} ]; then
	do_update
fi

while [ 1 ]; do
	$AGENT_CMD
	STATUS=$?

	if [ "$STATUS" == "$ST_DO_UPDATE" ]; then
		echo "Starting agent update."
		do_update
		if [ "$?" == "1" ]; then
			echo "Update failed: "
			cat ${UPDATE_DIR}/${UPDATE_LOG}
		else
			echo "Update successful."
		fi
	elif [ "$STATUS" == "$ST_FATAL" ]; then
		echo "Got fatal status code from the agent, stopping."
		break
	elif [ "$STATUS" == "$ST_RESTART" ]; then
		echo "Immediate restart requested."
	elif [ "$STATUS" == "$ST_INIT_FAILED" ]; then
		echo "Initialization failed, restarting in 60 seconds."
		sleep 60
	elif [ "$STATUS" == "$ST_SERVER_DISABLED" ]; then
		echo "The server is disabled or inactive, checking again in 300 seconds."
		sleep 300
	else
		echo "Unknown status code $STATUS, restarting in 60 seconds."
		sleep 60
	fi
done

exit 1
