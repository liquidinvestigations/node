# Development on the Liquid bundle


## Debugging

Set the debug flag in `liquid.ini`:
```ini
[liquid]
debug = on
```

Then redeploy (`./liquid deploy`).

To log into the snoop docker container:
```shell
./liquid shell hoover:snoop
```

## Working on components

In order to work on Hoover Search, Hoover Snoop, or Liquid Core, first clone
the repositories:

```shell
cd repos
./clone.sh https  # or ./clone.sh ssh, based on preference
```

After that, set these flags in your configuration:

```ini
[liquid]
...
mount_local_repos = true

...

version_track = testing
```

And re-run `./liquid deploy`.


Whenever any of those repos' `master` branches are changed upstream, you must run `./clone https` again to update the ones you are not working on. The command will run `git pull --ff-only`, so it won't affect repositories where there is work in progress.


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
