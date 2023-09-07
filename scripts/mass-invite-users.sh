#!/bin/bash
set -e

# Script creates invitation links for many accounts.
# We then enable access for all accounts into all apps.

cd "$(dirname ${BASH_SOURCE[0]})/.."

NUM_USERS=100

USERNAME_PREFIX=anon.user

# time from today until the end of the demo 10 weeks in minutes = 10 * 7 * 24 * 60
EXPIRY_MIN=100800

OUT_FILE=/tmp/links.txt

SCRIPT1="$(cat <<EOF
set -e
export NUM_USERS=$NUM_USERS
export USERNAME_PREFIX=$USERNAME_PREFIX
export EXPIRY_MIN=$EXPIRY_MIN
export OUT_FILE=$OUT_FILE
EOF
)"


SCRIPT2="$(cat <<'EOF'
rm -f $OUT_FILE || true
touch $OUT_FILE

for i in $(seq 1 $NUM_USERS); do
    RANDOM_HASH=$(cat /dev/random | head -c200 | md5sum | cut -f1 -d' ')
    USERNAME="$USERNAME_PREFIX.$i.$RANDOM_HASH"
    INVITE_LINK="$(./manage.py invite --duration $EXPIRY_MIN --create $USERNAME | tail -n -1)"
    echo "$USERNAME,$INVITE_LINK" >> $OUT_FILE
done

cat $OUT_FILE
EOF
)"

./liquid dockerexec liquid:core bash -c "$SCRIPT1; $SCRIPT2" > mass-invite-users.csv


# allow all users access to all apps
./liquid dockerexec liquid:core ./manage.py shell <<EOF
from django.contrib.auth.models import User, Permission

from liquidcore.site.admin import all_permissions
perms = all_permissions()
perms = [k.split('.')[1] for k in perms]
perms = list(Permission.objects.filter(codename__in=perms).all())

users = list(User.objects.all())
for u in users:
    for perm in perms:
        u.user_permissions.add(perm)
    u.save()
    print(u, 'added perms: ', perms)

EOF

echo

echo "MASS USER CREATION DONE -- see $PWD/mass-invite-users.csv"
