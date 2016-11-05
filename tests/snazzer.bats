#!/usr/bin/env bats
# vi:syntax=sh

load "$BATS_TEST_DIRNAME/fixtures.sh"

setup() {
    export SNAZZER_SUBVOLS_EXCLUDE_FILE=$BATS_TEST_DIRNAME/data/exclude.patterns
    export SNAZZER_DATE=$(date +"%Y-%m-%dT%H%M%S%z")
    export MNT=$(prepare_mnt)
    export SNAZZER_TMP=$BATS_TMPDIR/snazzer-tests
    [ -e "$SNAZZER_SUBVOLS_EXCLUDE_FILE" ]
}

gather_snapshots() {
    su_do find "$MNT" | grep -v '[0-9]/' | grep '[0-9]$'
}

expected_snapshots() {
    [ -n "$MNT" -a -e "$SNAZZER_SUBVOLS_EXCLUDE_FILE" ]
    expected_list_subvolumes "$MNT" | sed "s|$|/.snapshotz/$SNAZZER_DATE|g"
}

expected_snapshots_raw() {
    [ -n "$SNAZZER_DATE" ]
    echo "$MNT/.snapshotz/$SNAZZER_DATE"
    gen_subvol_list | sed "s|^|$MNT/|g" | while read SUBVOL; do
        echo "$SUBVOL/.snapshotz/$SNAZZER_DATE"
    done
}

@test "btrfs mkfs.btrfs in PATH" {
    btrfs --help
    mkfs.btrfs --help
}

@test "snazzer in PATH" {
    readlink -f $BATS_TEST_DIRNAME/../snazzer > $(expected_file)
    readlink -f $(which snazzer) > $(actual_file)
    diff -u $(expected_file) $(actual_file)
}

@test "snazzer --all [mountpoint]" {
    run snazzer --all "$MNT"
    [ "$status" = "0" ]
    expected_snapshots | sort > $(expected_file)
    gather_snapshots | sort > $(actual_file)
    diff -u $(expected_file) $(actual_file)
}

@test "snazzer --dry-run --all [mountpoint]" {
    run snazzer --dry-run --all "$MNT"
    [ "$status" = "0" ]
    eval "$output"
    [ "$status" = "0" ]
    expected_snapshots | sort > $(expected_file)
    gather_snapshots | sort > $(actual_file)
    diff -u $(expected_file) $(actual_file)
}

@test "snazzer [subvol]" {
    run snazzer "$MNT/home"
    [ "$status" = "0" ]
    expected_snapshots_raw | grep "^$MNT/home" > $(expected_file)
    gather_snapshots | sort > $(actual_file)
    diff -u $(expected_file) $(actual_file)
}

@test "snazzer [subvol1] [subvol2] [subvol3]" {
    run snazzer "$MNT/home" "$MNT/srv" "$MNT/var/cache"
    [ "$status" = "0" ]
    expected_snapshots_raw | grep "^$MNT/\(home\|srv\|var/cache\)/\.snapshotz" \
        | sort > $(expected_file)
    gather_snapshots | sort > $(actual_file)
    diff -u $(expected_file) $(actual_file)
}

teardown() {
    teardown_mnt "$MNT" >/dev/null 2>/dev/null
}
