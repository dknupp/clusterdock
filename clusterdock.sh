#!/usr/bin/env bash
# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# This helper script is designed to be sourced, at which time its functions are made available
# to the user. Most functions defined have functionality defined by environmental variables, which
# can be set during invocation. For example,
#
# CLUSTERDOCK_PULL=false clusterdock_run ./bin/...

## @description  Run a clusterdock Python script within a Docker container
## @audience     public
## @stability    stable
## @replaceable  no
## @param        Python script to run relative to the ./dev-support/clusterdock/clusterdock folder
clusterdock_run() {
  # Supported environmental variables:
  # - CLUSTERDOCK_TARGET_DIR: a folder on the host to mount into /root/target in the clusterdock
  #                           container
  # - CLUSTERDOCK_PULL: whether to pull the clusterdock image (either true or false; defaults to
  #                     true)

  if [ -z "${CLUSTERDOCK_IMAGE}" ]; then
    local CONSTANTS_CONFIG_URL='https://raw.githubusercontent.com/cloudera/clusterdock/master/clusterdock/constants.cfg'

    # awk -F argument allows for any number of spaces around equal sign.
    local DOCKER_REGISTRY_URL=$(curl -s "${CONSTANTS_CONFIG_URL}" \
        | awk -F " *= *" '/^docker_registry_url/ {print $2}')
    local CLOUDERA_NAMESPACE=$(curl -s "${CONSTANTS_CONFIG_URL}" \
        | awk -F " *= *" '/^cloudera_namespace/ {print $2}')

    CLUSTERDOCK_IMAGE="${DOCKER_REGISTRY_URL}/${CLOUDERA_NAMESPACE}/clusterdock:latest"
  fi

  if [ "${CLUSTERDOCK_PULL}" != "false" ]; then
    sudo docker pull "${CLUSTERDOCK_IMAGE}"
  fi

  if [ -n "${CLUSTERDOCK_TARGET_DIR}" ]; then
    local TARGET_DIR_MOUNT="-v ${CLUSTERDOCK_TARGET_DIR}:/root/target"
  fi

  if [ -n "${CLUSTERDOCK_DOCKER_REGISTRY_INSECURE}" ]; then
    local REGISTRY_INSECURE="-e DOCKER_REGISTRY_INSECURE=${CLUSTERDOCK_DOCKER_REGISTRY_INSECURE}"
  fi

  if [ -n "${CLUSTERDOCK_DOCKER_REGISTRY_USERNAME}" ]; then
    local REGISTRY_USERNAME="-e DOCKER_REGISTRY_USERNAME=${CLUSTERDOCK_DOCKER_REGISTRY_USERNAME}"
  fi

  if [ -n "${CLUSTERDOCK_DOCKER_REGISTRY_PASSWORD}" ]; then
    local REGISTRY_PASSWORD="-e DOCKER_REGISTRY_PASSWORD=${CLUSTERDOCK_DOCKER_REGISTRY_PASSWORD}"
  fi

  # The /etc/hosts bind-mount allows clusterdock to update /etc/hosts on the host machine for
  # better access to internal container addresses.
  sudo docker run --net=host -t \
      --privileged \
      ${TARGET_DIR_MOUNT} \
      ${REGISTRY_INSECURE} \
      ${REGISTRY_USERNAME} \
      ${REGISTRY_PASSWORD} \
      -v /tmp/clusterdock \
      -v /etc/hosts:/etc/hosts \
      -v /etc/localtime:/etc/localtime \
      -v /var/run/docker.sock:/var/run/docker.sock \
      "${CLUSTERDOCK_IMAGE}" $@
}

## @description  SSH to a clusterdock-created container cluster node
## @audience     public
## @stability    stable
## @replaceable  no
## @param        Topology of the cluster
## @param        Fully-qualified domain name of container to which to connect
clusterdock_ssh() {
  local TOPOLOGY=${1}
  local NODE=${2}

  if [ -z "${CLUSTERDOCK_IMAGE}" ]; then
    local CONSTANTS_CONFIG_URL='https://raw.githubusercontent.com/cloudera/clusterdock/master/clusterdock/constants.cfg?token=AFzozBXZOifPpJLH0A5sRK9o5ssbeZaeks5Xm9VIwA%3D%3D'

    # awk -F argument allows for any number of spaces around equal sign.
    local DOCKER_REGISTRY_URL=$(curl -s "${CONSTANTS_CONFIG_URL}" \
        | awk -F " *= *" '/^docker_registry_url/ {print $2}')
    local CLOUDERA_NAMESPACE=$(curl -s "${CONSTANTS_CONFIG_URL}" \
        | awk -F " *= *" '/^cloudera_namespace/ {print $2}')

    CLUSTERDOCK_IMAGE="${DOCKER_REGISTRY_URL}/${CLOUDERA_NAMESPACE}/clusterdock:latest"
  fi

  if [ "${CLUSTERDOCK_PULL}" != "false" ]; then
    sudo docker pull "${CLUSTERDOCK_IMAGE}"
  fi

  # Some arguments to make SSH less finicky.
  local SSH_ARGS='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'

  # The /etc/hosts bind-mount allows clusterdock to update /etc/hosts on the host machine for
  # better access to internal container addresses.
  sudo docker run --entrypoint=bash -it --net=host --rm \
      ${TARGET_DIR_MOUNT} \
      -v /etc/hosts:/etc/hosts \
      -v /etc/localtime:/etc/localtime \
      -v /var/run/docker.sock:/var/run/docker.sock \
      "${CLUSTERDOCK_IMAGE}" -c \
      "ssh -i /root/clusterdock/clusterdock/topologies/${TOPOLOGY}/ssh/id_rsa ${SSH_ARGS} ${NODE}"
}
