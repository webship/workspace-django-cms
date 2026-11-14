"""The accounts of a django CMS site: its superuser, the default accounts, who is there.

Runs with the Python of the site's virtual environment inside the project's container, in the
folder of manage.py. The functions of the plugin (fun-django-cms.sh) pipe it to `python -` and
hand it what it needs in two variables:

  DJANGO_CMS_ACCOUNTS_VERB  installed | owner | add | cancel | list
  DJANGO_CMS_ACCOUNTS       base64 of a JSON object:
                            { owner: { name, email, password },
                              accounts: [{ name, email, password, role }] }   role: superuser | editor

Every verb can run again: what is already as asked is left alone. No password is ever printed.
"""
import base64
import json
import os
import sys

import django

os.environ.setdefault("DJANGO_SETTINGS_MODULE", os.environ.get("DJANGO_CMS_SETTINGS", "djangocmssite.settings"))
sys.path.insert(0, os.getcwd())
django.setup()

from django.contrib.auth import get_user_model  # noqa: E402
from django.contrib.auth.models import Group, Permission  # noqa: E402
from django.db.models import ProtectedError  # noqa: E402

User = get_user_model()
EDITORS = "Editors"
# What an editor works on: pages, plugins, versions, aliases and files. Not users, groups or
# page permissions.
EDITOR_APPS = ["cms", "djangocms_text", "djangocms_versioning", "djangocms_alias", "djangocms_link", "djangocms_frontend", "filer"]
ACCESS_MODELS = ["globalpagepermission", "pagepermission", "pageuser", "pageusergroup"]


def given():
    raw = os.environ.get("DJANGO_CMS_ACCOUNTS", "")
    return json.loads(base64.b64decode(raw).decode("utf-8")) if raw else {}


def editors_group():
    """The group an editor is in, with what it may do. With CMS_PERMISSION on, a user who is not
    a superuser also needs a global page permission."""
    group, _ = Group.objects.get_or_create(name=EDITORS)
    group.permissions.set(
        Permission.objects.filter(content_type__app_label__in=EDITOR_APPS).exclude(content_type__model__in=ACCESS_MODELS)
    )
    from cms.models import GlobalPagePermission
    from django.contrib.sites.models import Site

    permission, _ = GlobalPagePermission.objects.get_or_create(group=group)
    for field in ["can_change", "can_add", "can_delete", "can_publish", "can_change_advanced_settings", "can_move_page", "can_view"]:
        setattr(permission, field, True)
    permission.can_change_permissions = False
    permission.save()
    permission.sites.set(Site.objects.all())
    return group


def installed():
    if not User.objects.filter(is_superuser=True, is_active=True).exists():
        sys.exit(3)


def owner():
    person = given().get("owner") or {}
    user, created = User.objects.get_or_create(username=person["name"], defaults={"email": person["email"]})
    user.email = person["email"]
    user.is_staff = True
    user.is_superuser = True
    user.is_active = True
    user.set_password(person["password"])
    user.save()
    print("   %s is the superuser of the site%s." % (user.username, "" if created else " (it was there, and is set again)"))


def add():
    for person in given().get("accounts") or []:
        user = User.objects.filter(username=person["name"]).first()
        if user and user.is_active:
            print("   %s is already there." % user.username)
            continue
        if user:
            # Deactivated by an earlier cancel because it had written content: it comes back.
            user.is_active = True
        else:
            user = User(username=person["name"], email=person["email"])
        user.set_password(person["password"])
        user.is_staff = True
        user.is_superuser = person["role"] == "superuser"
        user.save()
        if person["role"] == "editor":
            user.groups.set([editors_group()])
        print("   %s added (%s)." % (user.username, "superuser" if user.is_superuser else "staff, in the group %s" % EDITORS))


def cancel():
    for person in given().get("accounts") or []:
        user = User.objects.filter(username=person["name"]).first()
        if not user:
            print("   %s is not there." % person["name"])
            continue
        try:
            user.delete()
            print("   %s deleted." % person["name"])
        except ProtectedError:
            # The site keeps who created each version of a page, and will not lose it.
            user.is_active = False
            user.save()
            print("   %s has written page versions the site keeps, so it is deactivated instead of deleted." % person["name"])
    group = Group.objects.filter(name=EDITORS).first()
    if group and not group.user_set.exists():
        group.delete()
        print("   the group %s is empty and is deleted." % EDITORS)


def listing():
    for user in User.objects.order_by("-is_superuser", "username"):
        role = "superuser" if user.is_superuser else ("staff" if user.is_staff else "user")
        groups = ", ".join(user.groups.values_list("name", flat=True))
        print("   %-24s %-28s %-10s %s%s" % (user.username, user.email, role, groups, "" if user.is_active else " (not active)"))


VERBS = {"installed": installed, "owner": owner, "add": add, "cancel": cancel, "list": listing}
verb = os.environ.get("DJANGO_CMS_ACCOUNTS_VERB", "")
if verb not in VERBS:
    print("django-cms-accounts.py: DJANGO_CMS_ACCOUNTS_VERB is one of installed, owner, add, cancel, list")
    sys.exit(2)
VERBS[verb]()
