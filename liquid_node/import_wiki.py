import os
import subprocess
import requests
import json
import click
import logging
from .configuration import config

log = logging.getLogger(__name__)

# Configuration
XWIKI_USER = "superadmin"
WIKIJS_EXPORT_DIR_HOST = "/tmp/wikijs_backup"  # Root directory of your HTML wiki
WIKIJS_EXPORT_DIR_CONTAINER = "/tmp/backup"  # Root directory of your HTML wiki
DOKUWIKI_ROOT = "/opt/node/volumes/dokuwiki/data/dokuwiki/data/pages"


@click.group()
def import_wiki_commands():
    pass


def get_xwiki_password():
    """Retrieve XWiki password using the liquid CLI command and parse JSON output."""
    try:
        result = subprocess.run(
            ["./liquid", "getsecret", "liquid/xwiki/xwiki.superadmin"],
            capture_output=True,
            text=True,
            check=True
        )
        sanitized_output = result.stdout.replace("'", '"')
        secret_data = json.loads(sanitized_output)  # Parse JSON output
        return secret_data.get("secret_key")  # Extract the password
    except (subprocess.CalledProcessError, json.JSONDecodeError, KeyError) as e:
        log.warning(f"Error retrieving password: {e}")
        return None


def convert_html_to_xwiki(html_file):
    output = subprocess.run(
        ["pandoc", "-f", "html", "-t", "xwiki", html_file],
        capture_output=True,
        text=True
    )
    return output.stdout


def convert_dokuwiki_to_xwiki(dokuwiki_file):
    output = subprocess.run(
        ["pandoc", "-f", "dokuwiki", "-t", "xwiki", dokuwiki_file],
        capture_output=True,
        text=True
    )
    return output.stdout


def sanitize_cdata(content):
    """Ensure that `]]>` does not break CDATA by splitting it safely."""
    return content.replace("]]>", "]]]]><![CDATA[>")


def get_base_url():
    """Retrieve the base URL of the XWiki instance."""
    return config.nomad_url.rsplit(':', 1)[0]


def get_xwiki_page_url(space, page_name):
    """Construct XWiki REST API URL for a page."""
    xwiki_url = f'{get_base_url()}:{config.port_xwiki}/rest/wikis/xwiki/spaces'
    return f"{xwiki_url}/{space}/pages/{page_name}"


def upload_to_xwiki(space, page_name, xwiki_content, xwiki_password, parent_page=None):
    """Upload the converted XWiki content to XWiki via REST API."""
    url = get_xwiki_page_url(space, page_name)
    headers = {"Content-Type": "application/xml"}
    sanitized_content = sanitize_cdata(xwiki_content)

    xml_payload = f"""
<page xmlns="http://www.xwiki.org">
        <title>{page_name}</title>
        <syntax>xwiki/2.0</syntax>
        <content><![CDATA[{sanitized_content}]]></content>
        {'<parent>' + parent_page + '</parent>' if parent_page else ''}
</page>
    """

    response = requests.put(
        url, auth=(XWIKI_USER, xwiki_password), headers=headers, data=xml_payload
    )

    if response.status_code in [200, 201, 202, 204]:
        log.info(f"Uploaded: {space}.{page_name}")
    else:
        log.warning(f"Failed to upload {space}.{page_name}: {response.text}")
        log.warning(f"Response code: {response.status_code}")


def process_directory(root_dir, xwiki_password, source_wiki="wikijs"):
    """Recursively process all HTML files and maintain directory structure."""
    match source_wiki:
        case "wikijs":
            file_extension = ".html"
            convert_function = convert_html_to_xwiki
        case "dokuwiki":
            file_extension = ".txt"
            convert_function = convert_dokuwiki_to_xwiki
        case _:
            log.error(f"Unsupported source wiki: {source_wiki}")
            return

    for dirpath, _, filenames in os.walk(root_dir):
        # Convert directory path to XWiki space format
        rel_path = os.path.relpath(dirpath, root_dir)
        space = rel_path.replace(os.sep, ".") if rel_path != "." else "Main"

        parent_space = ".".join(space.split(".")[:-1]) if "." in space else None

        for filename in filenames:
            if filename.endswith(file_extension):
                source_path = os.path.join(dirpath, filename)
                page_name = os.path.splitext(filename)[0]

                log.info(f"Processing: {source_path} -> {space}.{page_name}")

                xwiki_content = convert_function(source_path)
                upload_to_xwiki(space, page_name, xwiki_content, xwiki_password, parent_space)


def get_container_id(container_name):
    get_id_command = f"docker ps | grep {container_name} | awk '{{print $1}}'"
    id = subprocess.check_output(["/bin/bash", "-c", get_id_command], text=True).strip()
    return id


def copy_data_from_container(container_id, container_path, host_path):
    """Copy data from a Docker container to the host."""
    try:
        subprocess.run(
            ["docker", "cp", f"{container_id}:{container_path}", host_path],
            capture_output=True,
            text=True,
            check=True
        )
        log.info(f"Data copied successfully from {container_id}:{container_path} to {host_path}")
    except subprocess.CalledProcessError as e:
        log.warning(f"Error copying data: {e}")


def create_backup_directory_in_container(directory):
    """Create a backup directory if it does not exist."""
    try:
        create_dir_command = f"./liquid dockerexec wikijs:wikijs mkdir -p {directory}"
        subprocess.check_call(["/bin/bash", "-c", create_dir_command])
    except subprocess.CalledProcessError as e:
        log.warning(f"Error creating directory: {e}")


def check_output_dir_exists(dir):
    return os.path.exists(dir)


@import_wiki_commands.command()
def import_xwiki_from_wikijs():
    if check_output_dir_exists(WIKIJS_EXPORT_DIR_HOST):
        log.error(f"Directory {WIKIJS_EXPORT_DIR_HOST} exists already. Please remove it and try again.")
        exit(1)
    create_backup_directory_in_container(WIKIJS_EXPORT_DIR_CONTAINER)
    print(f"""
1. Go to your wiki.js admin interface

2. Under 'Modules > Storage > Local File System':
        - edit Path: '{WIKIJS_EXPORT_DIR_CONTAINER}'
        - click 'Activate' button (blue one, top right)
        - click 'Apply' button (green one, top right)
        - Press 'Dump all content to disk' at the bottom
        - Wait until the process is finished
          """
          )
    print("Press <y> to continue")
    user_input = input()
    if user_input != "y":
        print("Exiting...")
        exit(0)
    container_id = get_container_id("wiki.js")
    copy_data_from_container(container_id, WIKIJS_EXPORT_DIR_CONTAINER, WIKIJS_EXPORT_DIR_HOST)
    xwiki_password = get_xwiki_password()
    if xwiki_password:
        process_directory(WIKIJS_EXPORT_DIR_HOST, xwiki_password, source_wiki="wikijs")
    else:
        log.warning("Failed to retrieve XWiki password.")


@import_wiki_commands.command()
def import_xwiki_from_dokuwiki():
    xwiki_password = get_xwiki_password()
    if xwiki_password:
        process_directory(DOKUWIKI_ROOT, xwiki_password, source_wiki="dokuwiki")
    else:
        log.warning("Failed to retrieve XWiki password.")
