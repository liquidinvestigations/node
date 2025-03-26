import subprocess
import requests
import click
import logging
from .configuration import config
from . import_wiki import XWIKI_USER, get_xwiki_password, get_base_url

log = logging.getLogger(__name__)


@click.group()
def sync_users_xwiki_commands():
    pass


def get_usernames():
    usernames = []
    command = [
        "./liquid", "dockerexec", "liquid:core", "bash", "-c",
        "sqlite3 ./var/db.sqlite3 'select username from auth_user;'"
    ]
    try:
        result = subprocess.run(command, check=True, capture_output=True, text=True)
        output = result.stdout.strip()
        usernames = output.split("\n")
    except subprocess.CalledProcessError as e:
        log.warning("Error:", e.stderr)
    return usernames


def build_page_url(username):
    return f"{get_base_url()}:{config.port_xwiki}/rest/wikis/xwiki/spaces/XWiki/pages/{username}"


def upload_to_xwiki(url, xwiki_password, payload, http_method, username=""):
    headers = {"Content-Type": "application/xml"}

    response = http_method(
        url, auth=(XWIKI_USER, xwiki_password), headers=headers, data=payload
    )

    if response.status_code in [200, 201, 202, 204]:
        log.info(f"Created: resource for {username} at {url}")
    else:
        log.warning(f"Failed to create user object for {username}: {response.text}")
        log.warning(f"Response code: {response.status_code}")


def create_xwiki_page(username, xwiki_password):
    """Create a new user page in XWiki."""
    url = build_page_url(username)

    xml_payload = f"""
<page xmlns="http://www.xwiki.org">
        <title>{username}</title>
        <syntax>xwiki/2.0</syntax>
    <hidden>false</hidden>
    <content></content>
</page>
    """

    upload_to_xwiki(url, xwiki_password, xml_payload, requests.put, username)


def create_user_object(username, xwiki_password):
    """Create a new user object in the XWiki page."""
    url = f"{build_page_url(username)}/objects"

    xml_payload = f"""
<object xmlns="http://www.xwiki.org">
  <name>XWiki.{username}</name>
  <number>0</number>
  <className>XWiki.XWikiUsers</className>
  <property name="active">
    <value>1</value>
  </property>
  <property name="email_checked">
    <value>1</value>
  </property>
</object>
    """

    upload_to_xwiki(url, xwiki_password, xml_payload, requests.post, username)


def create_oidc_object(username, xwiki_password):
    """Create a new OIDC object in the XWiki page."""
    url = f"{build_page_url(username)}/objects"

    xml_payload = f"""
<object xmlns="http://www.xwiki.org">
    <name>XWiki.{username}</name>
    <number>0</number>
    <className>XWiki.OIDC.UserClass</className>
    <property name ="issuer">
      <value>https://liquid.example.org</value>
      <value>{config.liquid_http_protocol}://{config.liquid_domain}</value>
    </property>
    <property name="subject">
      <value>{username}</value>
    </property>
  </object>
    """
    upload_to_xwiki(url, xwiki_password, xml_payload, requests.post, username)


def check_user_exists(username, xwiki_password):
    url = f"{build_page_url(username)}/objects"
    response = requests.get(url, auth=(XWIKI_USER, xwiki_password))
    if 'UserClass' in response.text:
        return True
    return False


def create_xwiki_user(username, xwiki_password):
    create_xwiki_page(username, xwiki_password)
    create_user_object(username, xwiki_password)
    create_oidc_object(username, xwiki_password)


@sync_users_xwiki_commands.command()
def sync_users_with_xwiki():
    xwiki_password = get_xwiki_password()
    usernames = get_usernames()
    for user in usernames:
        if check_user_exists(user, xwiki_password):
            log.info(f"User {user} already exists in XWiki")
            continue
        create_xwiki_user(user, xwiki_password)
