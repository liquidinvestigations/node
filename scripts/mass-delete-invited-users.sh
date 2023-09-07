#!/bin/bash
set -e

# Script to delete all users created by the mass invite script.

cd "$(dirname ${BASH_SOURCE[0]})/.."

USERNAME_PREFIX=anon.user

./liquid dockerexec liquid:core ./manage.py shell <<EOF
from django.contrib.auth.models import User
to_delete = User.objects.filter(username__startswith="$USERNAME_PREFIX").all()
print('to delete: ', len(to_delete))
User.objects.filter(pk__in=[d.pk for d in to_delete]).delete()

EOF

echo

echo "MASS DELETE DONE"
