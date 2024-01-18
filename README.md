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

### Defining Questions

The required parameters for each cluster type are different so that different questions will be asked based on the selected type when running `bin/profile configure`. For this reason, each type needs an independent YAML file to define the questions for that type. For instance, when configuring a Jupyter standalone cluster, a set of subsequent questions could be read from a file named 'path/to/openflight-jupyter-standalone/metadata.yaml'. In this section, the structure of the question YAML file will be discussed.

#### The Minimum Structure of Question Metadata YAML Files

The basic structure of the YAML file is shown below:
```
---
id: openflight-jupyter-standalone   # the unique id of the cluster type
name: 'Openflight Jupyter Standalone'   # the name of the cluster type
description: 'A Single Node Research Environment running Jupyter Notebook'  # the description of the cluster type
questions:  # define the list of questions for this cluster type
  - id: question_1          # the unique id of the question
    env: QUESTION_1         # the name of the environment variable to which the answer will be assigned. it should also be unique.
    text: 'question_1:'     # the text of the prompt that will be printed on the console as the label of the input field
    default: answer_1       # the default answer to the question
    validation:             # specify the validation for the answer
      type: string          # specify the type of the answer, this option is currently not actually validated but there must be at least one validation item for each question
  - id: question_2          # second question 
    env: QUESTION_2
    text: 'question_2:'
    default: answer_2
    validation:
      type: string
```
With the above example, two questions will be asked when configuring a Jupyter standalone cluster.

#### Validation: Format and Validation: Message

The `format` and the `message` come together as sub-parameters of `validation`. The former is used to validate whether the answer matches a specified regex pattern and the latter is used to show the corresponding error message when the answer is invalid. 
```
validation:
  format: '^[a-zA-Z0-9_\\-]+$'
  message: 'Invalid input: %{value}. Must contain only alphanumeric characters, - and _.'
```
For the above example, an error message `Invalid input: ab(d. Must contain only alphanumeric characters, - and _.` when the input answer is "ab(d".

#### Child Questions

Some questions may need to be presented based on the answer to the previous question. The following example gives the approach to define such child questions.
```
questions:
  - id: parent_question
    env: PARENT_QUESTION
    text: 'parent_question:'
    default: child
    validation:
      type: string
    questions:                          # define the child questions
      - id: child_question_daughter
        where: daughter                     # define the condition for asking this child question
        env: CHILD_QUESTION_DAUGHTER
        text: 'child_question_daughter:'
        default: daughter
        validation:
          type: string
      - id: child_question_son
        where: son
        env: CHILD_QUESTION_SON
        text: 'child_question_son:'
        default: son
        validation:
          type: string
```
For this metadata, the `parent_question` will be asked first. Then, if the answer is "daughter", only the `child_question_daughter` will be asked according to the given `where` option, and the `child_question_son` will be skipped. Note that if the answer is neither "daughter" nor "son", "moose", say, then both child questions will not be asked.

#### Boolean Questions

Some questions may want to get a binary answer, i.e. y/yes or n/no. To define such questions, a `type` parameter can be used as demonstrated below:
```
questions:
  - id: conditional_question
    env: CONDITIONAL_QUESTION
    text: "conditional_question:"
    type: boolean
    default: TRUE
    validation:
      type: bool    # remember that what is defined under the validation does not really matter but currently at least one validation item must be included
```
For this kind of questions, only yes, y, no, or n a valid answers.

Boolean questions can also have child questions. Simply use `true` or `false` as the value of the `where` option for the child questions of a boolean question.

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
