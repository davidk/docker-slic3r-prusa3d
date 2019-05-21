workflow "Update and build PrusaSlicer" {
  resolves = ["buildpush prusaslicer"]
  on = "push"
  # on = "schedule(0 8 * * *)"
}

action "login" {
  uses = "actions/docker/login@c08a5fc9e0286844156fefff2c141072048141f6"
  secrets = [
    "DOCKER_USERNAME",
    "DOCKER_PASSWORD",
  ]
}

## prusaslicer

action "check latest prusaslicer release" {
  uses = "actions/bin/sh@master"
  needs = ["login"]
  secrets = [
    "GITHUB_TOKEN",
  ]
  args = ["apt-get update", "apt-get -y install curl jq git", "./checkForLatestSlic3r.sh"]
}

action "buildpush prusaslicer" {
  uses = "davidk/docker/cli-multi@cli-loop"
  needs = ["check latest prusaslicer release"]
  args = [
    "build -t keyglitch/docker-slic3r-prusa3d:latest -f /github/workspace/Dockerfile .",
    "tag keyglitch/docker-slic3r-prusa3d:latest keyglitch/docker-slic3r-prusa3d:$(cat /github/workspace/VERSION)",
    "tag keyglitch/docker-slic3r-prusa3d:latest keyglitch/prusaslicer:latest",
    "tag keyglitch/prusaslicer:latest keyglitch/prusaslicer:$(cat /github/workspace/VERSION)",
    "push keyglitch/docker-slic3r-prusa3d",
  ]
}
