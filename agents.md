# AI Agent Guidelines for Coverband Development

This document provides guidance for AI coding agents working on the Coverband project. Following these guidelines ensures code quality and consistency.

## Project Overview

Coverband is a Ruby gem that provides rack middleware to measure production code usage (LOC runtime usage). The project uses:
- **Ruby**: >= 3.1
- **Test Framework**: Minitest (version ~> 5.0)
- **Code Style**: StandardRB
- **CI/CD**: GitHub Actions

## Testing Requirements

### Running Tests

All code changes MUST pass the test suite before considering work complete. The project has multiple test targets:

#### Standard Test Suite
```bash
bundle exec rake test
```
This runs the main integration and unit tests located in:
- `test/integration/**/*_test.rb`
- `test/coverband/**/*_test.rb`

#### Forked Tests
```bash
bundle exec rake forked_tests
```
Runs tests that require forked processes (Rails integration tests):
- `test/forked/**/*_test.rb`

Note: Forked tests are not supported on JRuby.

#### Full Test Suite
```bash
bundle exec rake test:all
```
Runs all tests including benchmarks and memory tests.

#### Default Task
```bash
bundle exec rake
```
Equivalent to `bundle exec rake test`

### Test Framework Details

- Uses **Minitest** with **Mocha** for mocking
- Test files follow the pattern `*_test.rb`
- Rails integration tests use **Capybara** for browser testing
- Forked tests use `minitest-fork_executor` for parallel execution

### Test Configuration

Key test dependencies:
- `minitest ~> 5.0` (pinned for compatibility with minitest-fork_executor)
- `mocha` for mocking/stubbing
- `minitest-stub-const` for constant stubbing
- `capybara` for integration testing
- `rack-test` for Rack testing

## Code Style Requirements

### StandardRB

All code MUST pass StandardRB linting before considering work complete.

```bash
bundle exec standardrb --format github
```

#### Auto-fix Style Issues
```bash
bundle exec standardrb --fix
```

### Configuration

StandardRB configuration is in `.standard.yml`:
- Ruby version: 3.1
- Parallel execution enabled
- Some rules are disabled for compatibility with older Ruby versions
- Test files have relaxed rules (see `.standard.yml` for specifics)

### Common Style Requirements

1. **Module Inclusions**: Add an empty line after `extend` or `include` statements
2. **Frozen String Literals**: All Ruby files should start with `# frozen_string_literal: true`
3. **Line Length**: Follow StandardRB defaults (no manual line length configuration needed)

## AI Agent Workflow

When making code changes, follow this workflow:

### 1. Make Code Changes
Implement the requested feature or bug fix.

### 2. Run Tests
```bash
bundle exec rake test
```

If working on Rails integration or forked features:
```bash
bundle exec rake test:all
```

### 3. Fix Any Test Failures
- Read test output carefully
- Fix issues in the code
- Re-run tests until all pass

### 4. Check Code Style
```bash
bundle exec standardrb --format github
```

### 5. Auto-fix Style Issues (if any)
```bash
bundle exec standardrb --fix
```

### 6. Verify Everything Passes
```bash
bundle exec rake test
bundle exec standardrb --format github
```

### 7. Only Then Consider Work Complete
Do NOT mark work as complete or hand back to the user until:
- ✅ All tests pass
- ✅ StandardRB reports no violations

## Common Issues and Solutions

### Mocha Configuration
- Use only Mocha 3.x compatible configuration options
- Valid options: `stubbing_method_unnecessarily`, `stubbing_non_public_method`
- Invalid options (removed): `stubbing_method_on_nil`, `stubbing_method_on_non_mock_object`, `stubbing_non_existent_method`

### Rails Constant Checks
When checking if Rails is defined:
```ruby
# ✅ Correct
if defined?(Rails) && Rails.respond_to?(:version)
  # ...
end

# ❌ Wrong (doesn't protect against undefined constant)
if Rails&.respond_to?(:version)
  # ...
end
```

### Minitest Version
- Must use Minitest ~> 5.0 for compatibility with `minitest-fork_executor`
- Minitest 6.0+ is not compatible with the fork executor

## CI/CD

The project uses GitHub Actions for CI. On every push/PR:
1. Tests run against multiple Ruby versions (3.1, 3.2, 3.3, 3.4, ruby-head)
2. Tests run against multiple Rails versions (7.0, 7.1, 7.2, 8.0)
3. Tests run against multiple Redis versions (4, 5, 6, 7)
4. StandardRB runs separately to check code style

Your local testing should match CI requirements:
- All tests must pass
- StandardRB must report no violations

## Additional Notes

- The project uses Redis as the default storage backend
- Rails 8.0 requires Ruby 3.2+
- Test coverage data is stored in `/tmp` during tests
- Use `test_helper.rb` for common test setup
- Use `rails_test_helper.rb` for Rails-specific test setup

## Example Complete Workflow

```bash
# 1. Make changes to code
vim lib/coverband/some_file.rb

# 2. Run tests
bundle exec rake test

# 3. Fix any failures, re-run until passing
bundle exec rake test

# 4. Check style
bundle exec standardrb --format github

# 5. Auto-fix any style issues
bundle exec standardrb --fix

# 6. Final verification
bundle exec rake test
bundle exec standardrb --format github

# 7. All green? Work is complete! ✅
```

## Quick Reference

| Command | Purpose |
|---------|---------|
| `bundle exec rake` | Run main test suite (default) |
| `bundle exec rake test` | Run main test suite |
| `bundle exec rake forked_tests` | Run forked/Rails integration tests |
| `bundle exec rake test:all` | Run all tests including benchmarks |
| `bundle exec standardrb --format github` | Check code style |
| `bundle exec standardrb --fix` | Auto-fix style issues |

Remember: **Tests and style checks must pass before work is considered complete!**
