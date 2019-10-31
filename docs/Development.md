# Development on the Liquid bundle


## Debugging

Set the debug flag in `liquid.ini`:
```ini
[liquid]
debug = on
```

Then redeploy (`./liquid deploy`).

To log into the snoop docker container for testdata:
```shell
./liquid shell snoop-testdata-api
```

To dump the nginx configuration:
```shell
nomad alloc fs $(./liquid alloc liquid nginx) nginx/local/core.conf
```


## Working on components

In order to work on Hoover Search, Hoover Snoop, or Liquid Core, first clone
the repositories:

```shell
cd repos
./clone.sh https  # or ./clone.sh ssh, based on preference
```

After that, set this flag in your configuration:

```ini
[liquid]
...
mount_local_repos = true
```


## Stopping jobs that should not be running in the current deploy configuration

This command will stop all jobs from collections that are no longer in the
`liquid.ini` file and jobs from applications that were disabled.

```bash
./liquid gc
```


## Removing dead jobs from nomad

In order to remove dead jobs from nomad run the following command:
`./liquid nomadgc`.


## Enabling/disabling applications
Applications can be enabled/disabled on deploy by setting them `on` or `off`
in the `apps` section:
```ini
[apps]
nextcloud = off
```

By default, all applications are started, but this default can also be changed
in the `deploy` section:
```ini
[apps]
default_app_status = off
```


## Running custom jobs

You can deploy your own jobs on the cluster. First, create a nomad job file,
you can use one of the existing `.nomad` files as a starting point. Save it in
the `local` folder, or outside the repository, so that it doesn't interfere
with updates. Then add the job to `liquid.ini`:

```ini
[job:foo]
template = local/foo.nomad
```

Afterwards, run `./liquid deploy`, which will send your job `foo` to nomad.
