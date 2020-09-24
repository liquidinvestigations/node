#!/bin/sh -ex
./liquid dockerexec liquid:core ./manage.py shell <<EOF
from django.contrib.auth.models import User
admin = User.objects.create_user('admin', 'admin@example.com', 'adminpassword')
admin.is_superuser = True
admin.is_staff = True
admin.save()
print(admin)
john = User.objects.create_user('john', 'john@thebeatles.com', 'johnpassword')
print(john)
EOF