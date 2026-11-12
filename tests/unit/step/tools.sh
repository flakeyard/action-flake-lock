# shellcheck shell=bash
# Tests of scripts/step/tools.sh and scripts/lib/tools.sh, with the nix stub.
# shellcheck disable=SC2154 # work and state come from setup.

# fake_system SYSTEM: the nix stub runs on SYSTEM.
fake_system() {
  local system=$1
  printf '%s\n' "$system" >"$work/fixtures/nix-system"
}

# fake_record SYSTEM NAME PATH: tools.nix records PATH for the tool NAME on
# SYSTEM.
fake_record() {
  local system=$1 name=$2 path=$3
  printf '%s\n' "$path" >"$work/fixtures/nix-eval-$system.$name"
}

# fake_substitute PATH [PRINTED...]: the nix stub substitutes PATH and prints
# PRINTED, by default PATH.
fake_substitute() {
  local path=$1 printed
  shift
  (($#)) || set -- "$path"
  for printed; do
    printf '%s\n' "$printed" >>"$work/fixtures/nix-build-${path##*/}"
  done
}

# fake_tools SYSTEM: tools.nix records jq and gh for SYSTEM, and the nix stub
# runs on it and substitutes both.
fake_tools() {
  local system=$1 name
  fake_system "$system"
  for name in jq gh; do
    fake_record "$system" "$name" "$work/store/$system-$name"
    fake_substitute "$work/store/$system-$name"
  done
}

# expect_recorded NAME PATH: the step recorded PATH as the store path of NAME.
expect_recorded() {
  local name=$1 path=$2 file=$state/tools/$1
  [[ -z $current ]] || [[ -f $file && $(<"$file") == "$path" ]] \
    || report "recorded for $name: '$(cat "$file" 2>/dev/null)', expected '$path'"
}

action_setup
fake_tools x86_64-linux
run "tools: substitutes the recorded jq and gh" ok scripts/step/tools.sh
expect call "nix config show system"
expect call "nix eval --raw --file $root/tools.nix x86_64-linux.jq"
expect call "nix build --no-link --print-out-paths $work/store/x86_64-linux-jq"
expect call "nix eval --raw --file $root/tools.nix x86_64-linux.gh"
expect call "nix build --no-link --print-out-paths $work/store/x86_64-linux-gh"
expect no-call "path:"
expect_recorded jq "$work/store/x86_64-linux-jq"
expect_recorded gh "$work/store/x86_64-linux-gh"
finish

action_setup
fake_tools aarch64-linux
run "tools: takes the paths of the system of nix" ok scripts/step/tools.sh
expect_recorded jq "$work/store/aarch64-linux-jq"
expect_recorded gh "$work/store/aarch64-linux-gh"
finish

action_setup
fake_tools x86_64-linux
fake_system riscv64-linux
run "tools: a system without recorded paths fails" fail scripts/step/tools.sh
expect message "tools.nix records no store path of jq for riscv64-linux."
expect no-call "nix build"
finish

action_setup
fake_tools x86_64-linux
fake_record x86_64-linux jq "$work/store/jq-bin"$'\n'"$work/store/jq-man"
run "tools: a record of two paths fails" fail scripts/step/tools.sh
expect message "tools.nix records no store path of jq for x86_64-linux."
expect no-call "nix build"
finish

action_setup
fake_tools x86_64-linux
fake_record x86_64-linux jq "$work/store/missing-jq"
run "tools: a path that no substituter has fails" fail scripts/step/tools.sh
expect message "Cannot substitute jq from $work/store/missing-jq"
finish

action_setup
fake_tools x86_64-linux
fake_record x86_64-linux jq "$work/store/other-jq"
fake_substitute "$work/store/other-jq" "$work/store/x86_64-linux-jq"
run "tools: a build that prints another path fails" fail scripts/step/tools.sh
expect message "nix build of jq printed '$work/store/x86_64-linux-jq', expected $work/store/other-jq."
finish

action_setup
run "tools: no nix on the PATH of the job" fail scripts/step/tools.sh PATH="$sysbin"
expect message "No nix on PATH"
expect no-calls
finish

action_setup
fake_tools x86_64-linux
rm -- "$work/fixtures/nix-system"
run "tools: a nix without a system fails" fail scripts/step/tools.sh
expect message "Cannot read the system of"
expect no-call "nix eval"
finish

action_setup
mkdir -p "$state"
touch "$state/lock.json"
fake_tools x86_64-linux
run "tools: starts the files of the steps afresh" ok scripts/step/tools.sh
[[ -z $current || ! -e $state/lock.json ]] || report "lock.json of an earlier run is left"
finish
