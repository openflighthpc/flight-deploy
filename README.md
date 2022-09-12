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

