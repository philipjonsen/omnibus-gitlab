---
stage: Systems
group: Distribution
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/product/ux/technical-writing/#assignments
---

# Maintenance commands **(FREE SELF)**

The following commands can be run after installation.

## Get service status

Run `sudo gitlab-ctl status` to see the current state and uptime of each GitLab component.

The output will look similar to this:

```plaintext
run: nginx: (pid 972) 7s; run: log: (pid 971) 7s
run: postgresql: (pid 962) 7s; run: log: (pid 959) 7s
run: redis: (pid 964) 7s; run: log: (pid 963) 7s
run: sidekiq: (pid 967) 7s; run: log: (pid 966) 7s
run: puma: (pid 961) 7s; run: log: (pid 960) 7s
```

As a demonstration, the first line of the previous example can be interpreted as follows:

- `Nginx` is the process name.
- `972` is the process identifier.
- NGINX has been running for 7 seconds (`7s`).
- `log` indicates a [svlogd logging process](https://manpages.ubuntu.com/manpages/lunar/en/man8/svlogd.8.html) attached to the preceding process.
- `971` is the process identifier for the logging process.
- The logging process has been running for 7 seconds (`7s`).

## Tail process logs

See [settings/logs.md.](../settings/logs.md)

## Starting and stopping

After Omnibus GitLab is installed and configured, your server has a runit
service directory (`runsvdir`) process running that gets started at boot via
`/etc/inittab` or the `/etc/init/gitlab-runsvdir.conf` Upstart resource. You
should not have to deal with the `runsvdir` process directly; you can use the
`gitlab-ctl` front-end instead.

You can start, stop or restart GitLab and all of its components with the
following commands.

```shell
# Start all GitLab components
sudo gitlab-ctl start

# Stop all GitLab components
sudo gitlab-ctl stop

# Restart all GitLab components
sudo gitlab-ctl restart
```

Note that on a single-core server it may take up to a minute to restart Puma and
Sidekiq. Your GitLab instance will give a 502 error until Puma is up again.

It is also possible to start, stop or restart individual components.

```shell
sudo gitlab-ctl restart sidekiq
```

Puma does support almost zero-downtime reloads. These can be triggered as
follows:

```shell
sudo gitlab-ctl hup puma
```

Note that you must wait for the `hup` command to finish. This could take some time. Leave the node out of the pool and do not restart services on the node where this is invoked until this completes. You also cannot use a Puma reload to update the Ruby runtime.

Puma has the following signals to control application behavior:

| Signal   | Puma                                                                |
| -------- | ------                                                              |
| `HUP`    | reopen log files defined, or stop the process to force restart      |
| `INT`    | gracefully stops requests processing                                |
| `USR1`   | restart workers in phases, a rolling restart, without config reload |
| `USR2`   | restart workers and reload config                                   |
| `QUIT`   | exit the main process                                               |

For Puma, `gitlab-ctl hup puma` will send a sequence of `SIGINT` and `SIGTERM`
(if process does not restart) signals. Puma stops accepting new connections as
soon as `SIGINT` is received. It finishes all running requests. Then `runit`
restarts the service.

## Invoking Rake tasks

To invoke a GitLab Rake task, use `gitlab-rake`. For example:

```shell
sudo gitlab-rake gitlab:check
```

Leave out `sudo` if you are the `git` user.

Contrary to with a traditional GitLab installation, there is no need to change
the user or the `RAILS_ENV` environment variable; this is taken care of by the
`gitlab-rake` wrapper script.

## Starting a Rails console session

For more information, see
[Rails console](https://docs.gitlab.com/ee/administration/operations/rails_console.html#starting-a-rails-console-session).

## Starting a PostgreSQL superuser `psql` session

If you need superuser access to the bundled PostgreSQL service you can
use the `gitlab-psql` command. It takes the same arguments as the
regular `psql` command.

```shell
# Superuser psql access to GitLab's database
sudo gitlab-psql -d gitlabhq_production
```

This will only work after you have run `gitlab-ctl reconfigure` at
least once. The `gitlab-psql` command cannot be used to connect to a
remote PostgreSQL server, nor to connect to a local non-Omnibus PostgreSQL
server.

### Starting a PostgreSQL superuser `psql` session in Geo tracking database

Similar to the previous command, if you need superuser access to the bundled
Geo tracking database (`geo-postgresql`), you can use the `gitlab-geo-psql`.
It takes the same arguments as the regular `psql` command. For HA, see more
about the necessary arguments in:
[Checking Configuration](https://docs.gitlab.com/ee/administration/geo/replication/troubleshooting.html#checking-configuration)

```shell
# Superuser psql access to GitLab's Geo tracking database
sudo gitlab-geo-psql -d gitlabhq_geo_production
```

## Container Registry garbage collection

Container Registry can use considerable amounts of disk space. To clear up
unused layers, the registry includes a
[garbage collect command](https://docs.gitlab.com/ee/administration/packages/container_registry.html#container-registry-garbage-collection).

## Restrict users from logging into GitLab

If you need to temporarily restrict users from logging into GitLab, you can use
`sudo gitlab-ctl deploy-page up`. When a user goes to your GitLab URL, they
will be shown an arbitrary `Deploy in progress` page.

To remove the page, you simply run `sudo gitlab-ctl deploy-page down`. You can also check the status of the deploy page with `sudo gitlab-ctl deploy-page status`.

As a side note, if you would like to restrict logging into GitLab and restrict
changes to projects, you can [set projects as read-only](https://docs.gitlab.com/ee/administration/troubleshooting/gitlab_rails_cheat_sheet.html#make-a-project-read-only-can-only-be-done-in-the-console)
, then put up the `Deploy in progress` page.
