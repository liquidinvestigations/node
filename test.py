from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.remote.command import Command

import http.client
import socket
import pytest

ADMIN_USERNAME = "admin"
ADMIN_PASSWORD = "adminpassword"
LIQUID_CORE_URL = "https://timisoara.alt-f4.ro/"
LIQUID_TITLE = "Liquid Example Org"
TIME_TO_WAIT = 10


def init_driver():
    try:
        driver = webdriver.Remote('http://localhost:4444/wd/hub', webdriver.DesiredCapabilities.FIREFOX)
        driver.set_window_size(1280, 1024)
        driver.get(LIQUID_CORE_URL)
        return driver
    except:
        return None


def do_login(driver):
    driver.find_element_by_id("id_username").send_keys(ADMIN_USERNAME)
    driver.find_element_by_id("id_password").send_keys(ADMIN_PASSWORD)
    driver.find_element_by_xpath('//button[text()="login"]').click()
    return driver


@pytest.fixture
def web_driver():
    driver = webdriver.Remote('http://localhost:4444/wd/hub', webdriver.DesiredCapabilities.FIREFOX)
    driver.set_window_size(1280, 1024)
    driver.get(LIQUID_CORE_URL)
    driver.implicitly_wait(TIME_TO_WAIT)
    yield driver
    driver.quit()


def do_logout(driver):
    driver.find_element_by_link_text("[logout]").click()


def is_logged_in(web_driver):
    return web_driver.find_element_by_xpath(f"//*[contains(text(), '{LIQUID_TITLE}')]")


@pytest.mark.usefixtures("web_driver")
def test_login(web_driver):
    do_login(web_driver)
    assert is_logged_in(web_driver)


@pytest.mark.usefixtures("web_driver")
def test_logout(web_driver):
    do_login(web_driver)
    do_logout(web_driver)


def logout_hoover(driver):
    driver.find_element(By.XPATH, f"//*[contains(text(),'logout ({ADMIN_USERNAME})')]").click()


def login_hoover(driver):
    driver.find_element_by_link_text('Hoover').click()


@pytest.mark.usefixtures("web_driver")
def test_hoover(web_driver):
    do_login(web_driver)
    login_hoover(web_driver)
    logout_hoover(web_driver)


def login_dokuwiki(driver):
    driver.find_element_by_link_text("DokuWiki").click()
    driver.find_element_by_xpath(f"//*[contains(text(), '{ADMIN_USERNAME}')]")



def logout_dokuwiki(driver):
    driver.find_element_by_link_text('Log Out').click()


@pytest.mark.usefixtures("web_driver")
def test_dokuwiki(web_driver):
    do_login(web_driver)
    login_dokuwiki(web_driver)
    logout_dokuwiki(web_driver)


def login_hypothesis(driver):
    driver.find_element_by_link_text("Hypothesis").click()
    driver.find_element_by_xpath("//*[contains(text(), 'Welcome to Hypothesis!')]")
    driver.find_element_by_xpath(f"//*[contains(text(), '{ADMIN_USERNAME}')]")



@pytest.mark.usefixtures("web_driver")
def test_hypothesis(web_driver):
    do_login(web_driver)
    login_hypothesis(web_driver)


def login_codimd(driver):
    driver.find_element_by_link_text("CodiMD").click()
    driver.find_element_by_xpath(f"//*[contains(text(), '{ADMIN_USERNAME}')]")

@pytest.mark.usefixtures("web_driver")
def test_codimd(web_driver):
    do_login(web_driver)
    login_codimd(web_driver)


def login_rocketchat(driver):
    driver.find_element_by_link_text("Rocket.Chat").click()

@pytest.mark.usefixtures("web_driver")
def test_codimd(web_driver):
    do_login(web_driver)
    login_rocketchat(web_driver)

def login_nextcloud(driver):
    driver.find_element_by_link_text("Nextcloud").click()
    try:
        driver.find_element_by_id("login-uploads").click()
    except:
        pass
    driver.find_element_by_xpath(f"//*[contains(text(), 'All files')]")


@pytest.mark.usefixtures("web_driver")
def test_nextcloud(web_driver):
    do_login(web_driver)
    login_nextcloud(web_driver)

