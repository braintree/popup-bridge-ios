require 'tempfile'
require 'fileutils'
require 'shellwords'
require 'bundler'
Bundler.require
HighLine.color_scheme = HighLine::SampleColorScheme.new

task :default => %w[spec:all]

desc "Run tests"
task :spec => %w[spec:all]

desc "Run internal release steps"
task :release => %w[release:assumptions demo_app:build_demo spm:build_demo release:check_working_directory release:bump_version release:lint_podspec release:tag]

desc "Publish code and pod to public github.com"
task :publish => %w[publish:push publish:push_pod]

SEMVER = /\d+\.\d+\.\d+(-[0-9A-Za-z.-]+)?/
PODSPEC = "PopupBridge.podspec"
DEMO_PLIST = "Demo/Demo/Info.plist"
POPUPBRIDGE_FRAMEWORKS_PLIST = "Sources/PopupBridge/PopupBridge-Framework-Info.plist"
PUBLIC_REMOTE_NAME = "origin"

class << self
  def run cmd
    say(HighLine.color("$ #{cmd}", :debug))
    File.popen(cmd) { |file|
      if block_given?
        result = ''
        result << file.gets until file.eof?
        yield result
      else
        puts file.gets until file.eof?
      end
    }
    $? == 0
  end

  def run! cmd
    run(cmd) or fail("Command failed with non-zero exit status #{$?}:\n$ #{cmd}")
  end

  def current_version
    File.read(PODSPEC)[SEMVER]
  end

  def current_version_with_sha
    %x{git describe}.strip
  end

  def current_branch
    %x{git rev-parse --abbrev-ref HEAD}.strip
  end

  def xcodebuild(scheme, command, configuration)
    return "set -o pipefail && xcodebuild -workspace 'PopupBridge.xcworkspace' -sdk 'iphonesimulator' -configuration '#{configuration}' -scheme '#{scheme}' -destination 'name=iPhone 12,platform=iOS Simulator,OS=14.3' #{command} | xcpretty -c -r junit"
  end

end

namespace :spec do
  def run_test_scheme! scheme
    run! xcodebuild(scheme, 'test', 'Release')
  end

  desc 'Run unit tests'
  task :unit do
    run_test_scheme! 'UnitTests'
  end

  desc 'Run UI tests'
  task :ui do
    run_test_scheme! 'UITests'
  end

  desc 'Run all spec schemes'
  task :all => %w[spec:unit spec:ui]
end

namespace :demo_app do
  desc 'Verify that the demo app builds successfully'
  task :build_demo do
    run! xcodebuild('Demo', 'build', 'Release')
  end
end

namespace :spm do
  def update_xcodeproj
    project_file = "SampleApps/SPMTest/SPMTest.xcodeproj/project.pbxproj"
    proj = File.read(project_file)
    proj.gsub!(/(repositoryURL = )(.*);/, "\\1\"file://#{Dir.pwd}/\";")
    proj.gsub!(/(branch = )(.*);/, "\\1\"#{current_branch}\";")
    File.open(project_file, "w") { |f| f.puts proj }
  end

  task :build_demo do
    update_xcodeproj

    # Build SPMTest app
    run! "cd SampleApps/SPMTest && swift package resolve"
    run! "xcodebuild -project 'SampleApps/SPMTest/SPMTest.xcodeproj' -scheme 'SPMTest' clean build"

    # Cleanup
    run! 'rm -rf ~/Library/Developers/Xcode/DerivedData'
    run! 'git checkout SampleApps/SPMTest'
  end
end

namespace :release do
  desc "Print out pre-release checklist"
  task :assumptions do
    say "Release Assumptions"
    say "* [ ] You have pulled the latest public code from github.com."
    say "* [ ] You are on the branch and commit you want to release."
    say "* [ ] You have already merged hotfixes and pulled changes."
    say "* [ ] You have already reviewed the diff between the current release and the last tag, noting breaking changes in the semver and CHANGELOG."
    say "* [ ] Tests (rake spec) are passing, manual verifications complete."

    abort(1) unless ask "Ready to release? Press any key to continue. "
  end

  desc "Check that working directory is clean"
  task :check_working_directory do
    run! "echo 'Checking for uncommitted changes' && git diff --exit-code"
  end

  desc "Bump version in Podspec"
  task :bump_version do
    say "Current version in Podspec: #{current_version}"
    n = 10
    say "Previous #{n} versions in Git:"
    run "git tag -l | tail -n #{n}"
    version = ask("What version are you releasing?") { |q| q.validate = /\A#{SEMVER}\Z/ }

    podspec = File.read(PODSPEC)
    podspec.gsub!(/(s\.version\s*=\s*)'#{SEMVER}'/, "\\1\'#{version}\'")
    File.open(PODSPEC, "w") { |f| f.puts podspec }

    [DEMO_PLIST, POPUPBRIDGE_FRAMEWORKS_PLIST].each do |plist|
      run! "plutil -replace CFBundleVersion -string #{current_version} -- '#{plist}'"
      run! "plutil -replace CFBundleShortVersionString -string #{current_version} -- '#{plist}'"
    end
    run "git commit -m 'Bump pod version to #{version}' -- #{PODSPEC} Podfile.lock '#{DEMO_PLIST}' '#{POPUPBRIDGE_FRAMEWORKS_PLIST}'"
  end

  desc  "Lint podspec."
  task :lint_podspec do
    run! "pod lib lint --allow-warnings"
  end

  desc  "Tag."
  task :tag do
    run! "git tag #{current_version} -a -m 'Release #{current_version}'"
  end

end

namespace :publish do

  desc  "Push code and tag to github.com"
  task :push do
    run! "git push #{PUBLIC_REMOTE_NAME} HEAD #{current_version}"
  end

  desc  "Pod push."
  task :push_pod do
    run! "pod trunk push --allow-warnings PopupBridge.podspec"
  end

end
