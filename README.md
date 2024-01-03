# Flight Profile

Manage node provisioning.

## Overview

Flight Profile is an interactive node provisioning tool, providing an abstracted, command-line based system for the setup of nodes via Ansible or similar provisioning tools.

## Installation

### Manual installation

#### Prerequisites
Flight Profile is developed and tested with Ruby version 2.7.1 and bundler 2.1.4. Other versions may work but currently are not officially supported.

#### Steps

The following will install from source using Git. The master branch is the current development version and may not be appropriate for a production installation. Instead a tagged version should be checked out.

```bash
git clone https://github.com/openflighthpc/flight-profile.git
cd flight-profile
git checkout <tag>
bundle install --path=vendor
```

Flight Profile requires the presence of an adjacent `flight-profile-types` directory. The following will install that repository using Git.
```bash
cd /path/to/flight-profile/../
git clone https://github.com/openflighthpc/flight-profile-types.git
cd flight-profile-types
git checkout <tag>
```

This repository contains the cluster types that are used by Flight Profile.

## Configuration

To begin, run `bin/profile configure`. Here, you will set the cluster type to be used (present in `flight-profile-types`), as well as any required parameters specified in the metadata for that type.

These parameters must be set before you can run Flight Profile.

## Operation

A brief usage guide is given here. See the `help` command for more in depth details and information specific to each command.

Display the available cluster types with `avail`. A brief description of the purpose of each type is given along with its name. 

Display the available node identities with `identities`. These are what will be specified when setting up nodes. You can specify a type for which to list the identities with `identities TYPE`; if you don't specify, the type that was set in `configure` is used.

Set up one or more nodes with `apply HOSTNAME,HOSTNAME... IDENTITY`. Hostnames should be submitted as a comma separated list of valid and accessible hostnames on the network. The identity should be one that exists when running `identities` for the currently configured type.

List brief information for each node that has been set up with `list`.

View the setup status for a single node with `view HOSTNAME`. A truncated/stylised version of the Ansible output will be displayed, as well as the long-form command used to run it. See the raw log output by including the `--raw` option.

### Remove on shutdown option

When applying to a set of nodes, you may use the `--remove-on-shutdown` option. When used, the nodes being applied to will be given a `systemd` unit that, when stopped (presumably, on system shutdown), attempts to communicate to the applier node that they have shut down and should be `remove`'d from Profile. The option requires:

- The `shared_secret_path` config option to be set
- `flight-profile-api` set up and running on the same system, using the same shared secret

### Automatically obtaining node identities

When using `apply`, you may use the `--detect-identity` option to attempt to determine the identity of a node from its Hunter groups. The groups will be searched for a group name that matches an identity name, and if one is found, that node will be queued for an application of that identity.

When using the `--detect-identity` option, giving an identity is not required. However, you may still provide one, and that identity will be used for all nodes that could not automatically determine their own identity. For example, if you had a set of 50 nodes, you could modify the groups of one node to include "login", then run `profile apply node[0-49] compute --detect-identity` and the `compute` identity will be applied to the 49 other nodes which did not have modified groups, while `login` will be applied to the relevant node.

If you decide to apply an identity to a set of nodes while also using `--detect-identity`, if any of the nodes in that set determine their own identity to match the one you chose to apply, they will all be applied simultaneously.

# Contributing

Fork the project. Make your feature addition or bug fix. Send a pull
request. Bonus points for topic branches.

Read [CONTRIBUTING.md](CONTRIBUTING.md) for more details.

# Copyright and License

Eclipse Public License 2.0, see [LICENSE.txt](LICENSE.txt) for details.

Copyright (C) 2022-present Alces Flight Ltd.

This program and the accompanying materials are made available under
the terms of the Eclipse Public License 2.0 which is available at
[https://www.eclipse.org/legal/epl-2.0](https://www.eclipse.org/legal/epl-2.0),
or alternative license terms made available by Alces Flight Ltd -
please direct inquiries about licensing to
[licensing@alces-flight.com](mailto:licensing@alces-flight.com).

Flight Profile is distributed in the hope that it will be
useful, but WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, EITHER
EXPRESS OR IMPLIED INCLUDING, WITHOUT LIMITATION, ANY WARRANTIES OR
CONDITIONS OF TITLE, NON-INFRINGEMENT, MERCHANTABILITY OR FITNESS FOR
A PARTICULAR PURPOSE. See the [Eclipse Public License 2.0](https://opensource.org/licenses/EPL-2.0) for more
details.

