# flake8: noqa
import requests
import sys
# get rockatchat address and password
{{- range service "rocketchat-app" }}
url = 'http://{{.Address}}:{{.Port}}/'
{{- end }}
{{- with secret "liquid/rocketchat/adminuser" }}
data = {"user": "rocketchatadmin", "password": "{{.Data.pass }}"}
{{- end }}
domain = "${liquid_domain}"
# login to receive a token to authenticate with the api
response = requests.post(url + 'api/v1/login', data=data).json()
_id = response.get('data').get('me').get('_id')
token = response.get('data').get('authToken')
username = sys.argv[1]
headers = {'X-Auth-Token': token, 'X-User-Id': _id, 'Content-type': 'application/json'} # needed to authenticate
data = '{"name": "%s", "email": "%s@%s", "password": "pass", "username": "%s", "verified": true}' % (username, username, domain, username)
# call the rocketchat api to create user
response = requests.post(url + 'api/v1/users.create', headers=headers, data=data)
if response.status_code != 200:
    print("An error occured!")
    print("Got the following response from rocketchat:")
    print(response.content)
else:
    print("Created Rocketchat user " + username + ".")
requests.post(url + '/api/v1/logout', headers=headers)
