#!/bin/bash

# Function to check if user is logged into OpenShift and cluster is healthy
check_cluster_health() {
  echo "Verifying OpenShift login status..."

  # Check if the user is logged in
  if ! oc whoami &> /dev/null; then
    echo "❌ You are not logged into an OpenShift cluster. Please log in using 'oc login' and try again."
    return 1
  fi

  echo "✅ Logged into OpenShift as $(oc whoami)"

  # Check if the cluster is accessible and healthy
  if oc get clusterversion &> /dev/null; then
    echo "✅ Cluster is accessible and responding."
  else
    echo "❌ Cluster is not accessible or unhealthy."
    return 1
  fi
}

check_pipeline_status() {
  echo "Checking pipeline run status..."
  NAMESPACE="default"
  PIPELINE_RUN_PREFIX="cp4ba-cloud-pak-deployer-demos-run-"

  # Get the most recent matching PipelineRun
  LAST_RUN=$(oc get pipelineruns -n "$NAMESPACE" --sort-by=.metadata.creationTimestamp \
    | grep "$PIPELINE_RUN_PREFIX" | tail -1)

  if [[ -z "$LAST_RUN" ]]; then
    echo "❌ No matching PipelineRun found with prefix '$PIPELINE_RUN_PREFIX'."
    return 1
  fi

  # Extract the SUCCEEDED column (2nd column)
  LAST_RUN_STATUS=$(echo "$LAST_RUN" | awk '{print $2}')

  if [[ "$LAST_RUN_STATUS" == "True" ]]; then
    echo "✅ Last pipeline run was successful."
  else
    echo "❌ Last pipeline run was not successful. Status: $LAST_RUN_STATUS"
    return 1
  fi
}


# Function to check if configMap exists
check_configmap() {
  echo "Checking configMap existence..."
  if oc get configmap 000-client-onboarding-information -n cp4ba > /dev/null 2>&1; then
    echo "✅ Client Onboarding ConfigMap exists."
  else
    echo "❌ Client Onboarding ConfigMap does not exist."
    return 1
  fi
}

# Function to check services
check_services() {
  echo "Checking required services..."
  SERVICES=("icp4adeploy-navigator-svc" "icp4adeploy-cpe-stateless-svc" "icp4adeploy-css-svc-1")
  NAMESPACE="cp4ba"
  for svc in "${SERVICES[@]}"; do
    if oc get svc "$svc" -n "$NAMESPACE" > /dev/null 2>&1; then
      echo "✅ Service $svc is available."
    else
      echo "❌ Service $svc is not available."
      return 1
    fi
  done
}

# Initialize status flag
STATUS=0

# Run all checks individually
check_cluster_health || STATUS=1
check_pipeline_status || STATUS=1
check_configmap || STATUS=1
check_services || STATUS=1

# Evaluate overall result
if [ "$STATUS" -eq 0 ]; then
  echo "✅ All checks completed successfully."

  # Display only the 'data' field of the ConfigMap
  echo -e "\n📄 Key onboarding information from ConfigMap '000-client-onboarding-information':"
  oc get configmap 000-client-onboarding-information -n cp4ba -o jsonpath='{.data.information}' | fold -s
else
  echo "❌ One or more checks failed. Please review the messages above."
  exit 1
fi


