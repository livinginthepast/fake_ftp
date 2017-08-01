# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

### Changed

### Deprecated

### Removed

### Fixed

### Security

## [0.2.0] - 2017-06-26
### Added
- server: `size` command implementation

### Changed
- tests: updated ruby versions tested via Travis CI

## [0.1.1] - 2014-04-17
### Added
- documentation: more, plus a contributors doc

### Changed
- server:
  - fail to initialize if control or passive ports are invalid
  - reset port from initial server address

## [0.1.0] - 2013-09-30
### Added
- tests: integration with Travis CI
- documentation: GitHub-flavored markdown changes
- file: `last_modified_time`
- server:
  - wildcard support in `list` command
  - `mdtm` command implementation
  - `rnfr` command implementation
  - `rnto` command implementation
  - `dele` command implementation
  - `mkd` command implementation

### Changed
- server: real implementation of `cwd` command

## [0.0.9] - 2011-11-21
### Changed
- server: initial respond code `220`

## [0.0.8] - 2011-11-21
### Changed
- server: detect running state via `TCPSocket` instead of `lsof`

## [0.0.7] - 2011-10-07
### Added
- server: `reset` command to clear stored files

## [0.0.6] - 2011-06-12
### Changed
- server: pass args to commands via splat

## [0.0.5] - 2011-05-12
### Added
- file: accessors for data and created fields
- server:
  - `add_file` method for direct file addition
  - `retr` command implementation
  - `list` command implementation
  - `nlst` command implementation

## [0.0.4] - 2011-03-06
### Added
- docs: show how to test active upload

### Changed
- file: accept active/passive type at initialization

## [0.0.3] - 2011-03-06
### Added
- server:
  - initial active mode implementation
  - `port` command

### Changed
- server:
  - `stor` behavior depending on active/passive mode

## [0.0.2] - 2011-03-05
### Added
- file: initial implementation for in-memory store
- server:
  - `#files` method for fetching all stored file names
  - `#file` method for fetching rich file object by name

### Changed
- server: use in-memory store instead of local scratch directory

## 0.0.1 - 2011-02-28

### Added
- initial release with basic usage and docs

[Unreleased]: https://github.com/livinginthepast/fake_ftp/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/livinginthepast/fake_ftp/compare/v0.1.1...v0.2.0
[0.1.1]: https://github.com/livinginthepast/fake_ftp/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/livinginthepast/fake_ftp/compare/v0.0.9...v0.1.0
[0.0.9]: https://github.com/livinginthepast/fake_ftp/compare/v0.0.8...v0.0.9
[0.0.8]: https://github.com/livinginthepast/fake_ftp/compare/v0.0.7...v0.0.8
[0.0.7]: https://github.com/livinginthepast/fake_ftp/compare/v0.0.6...v0.0.7
[0.0.6]: https://github.com/livinginthepast/fake_ftp/compare/v0.0.5...v0.0.6
[0.0.5]: https://github.com/livinginthepast/fake_ftp/compare/v0.0.4...v0.0.5
[0.0.4]: https://github.com/livinginthepast/fake_ftp/compare/v0.0.3...v0.0.4
[0.0.3]: https://github.com/livinginthepast/fake_ftp/compare/v0.0.2...v0.0.3
[0.0.2]: https://github.com/livinginthepast/fake_ftp/compare/v0.0.1...v0.0.2
