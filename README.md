profile
=======

[![Build Status](https://ci.appveyor.com/api/projects/status/github/pyranja/profile)](https://ci.appveyor.com/project/pyranja/profile)
[![Latest Version](https://api.bintray.com/packages/pyranja/py-get/py-profile/images/download.svg)](https://bintray.com/pyranja/py-get/py-profile/_latestVersion)
[![License](https://img.shields.io/badge/license-unlicense-blue.svg)](http://unlicense.org/)

My personal .dotfiles and powershell scripts.

## Pre-requisites

`py-profile` requires at least powershell version 5.0 and the [chocolatey](https://chocolatey.org/) client.

## Installation

`py-profile` is available as chocolatey package in my personal nuget feed.

Set [PSGallery](https://www.powershellgallery.com/) as trusted module source _(Optional)_

    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted

Add the package feed to chocolatey

    choco sources add --source=https://api.bintray.com/nuget/pyranja/py-get --name=py-get

Install the `py-profile` package (this includes the py-ps powershell module)

    choco install py-profile

## Installing only `py-ps`

To install just the powershell scripts, use the built-in module manager

    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
    Install-Module py-ps

## Contributing

This project uses the [InvokeBuild](https://github.com/nightroman/Invoke-Build) build system. To get started clone or fork the repository and run:

    # install build system
    Install-Module Invoke-Build
    # install additional build dependencies
    Invoke-Build Bootstrap
    # run default build tasks
    Invoke-Build
