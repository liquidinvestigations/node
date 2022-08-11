# flake8: noqa
import requests
import sys
import os
# get rocketchat address and password
url = os.getenv('ROCKETCHAT_URL')
password = os.getenv('ROCKETCHAT_SECRET')
data = {"user": "rocketchatadmin", "password": password}
domain = os.getenv('LIQUID_DOMAIN')
# login to receive a token to authenticate with the api
response = requests.post(url + 'api/v1/login', data=data).json()
_id = response.get('data').get('me').get('_id')
token = response.get('data').get('authToken')
username = sys.argv[1]
headers = {'X-Auth-Token': token, 'X-User-Id': _id, 'Content-type': 'application/json'} # needed to authenticate
data = '{"username": "%s"}' % (username)
# call the rocketchat api to delete user
response = requests.post(url + 'api/v1/users.delete', headers=headers, data=data)
if response.status_code != 200:
    print('An error occured!')
    print('Got the following response from rocketchat:')
    print(response.content)
else:
    print(f'Deleted Rocketchat user: {username}.')
requests.post(url + '/api/v1/logout', headers=headers)
