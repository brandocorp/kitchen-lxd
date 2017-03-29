# <a name="title"></a> Kitchen::Lxd

A Test Kitchen Driver for Lxd.

## <a name="requirements"></a> Requirements

This driver depends on having the [LXD](https://github.com/lxc/lxd) command line client installed.

## <a name="installation"></a> Installation and Setup

```
gem install kitchen-lxd
```

## <a name="config"></a> Configuration

* `ssh_username` - The username to provide to ssh
* `ssh_key` - The openssh private key to use

## <a name="development"></a> Development

* Source hosted at [GitHub][repo]
* Report issues/questions/feature requests on [GitHub Issues][issues]

Pull requests are very welcome! Make sure your patches are well tested.
Ideally create a topic branch for every separate change you make. For
example:

1. Fork the repo
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## <a name="authors"></a> Authors

Created and maintained by [Brandon Raabe][author] (<brandocorp@gmail.com>)

## <a name="license"></a> License

Apache 2.0 (see [LICENSE][license])

[author]:           https://github.com/brandocorp
[issues]:           https://github.com/brandocorp/kitchen-lxd/issues
[license]:          https://github.com/brandocorp/kitchen-lxd/blob/master/LICENSE
[repo]:             https://github.com/brandocorp/kitchen-lxd
[driver_usage]:     http://docs.kitchen-ci.org/drivers/usage
[chef_omnibus_dl]:  http://www.chef.io/chef/install/
