#!/usr/bin/env ruby
# Usage: ./gui-release.sh <target_backend_branch> <source_frontend_branch> <service_name_1> <service_name_2>...

require 'git'
require 'tempfile'

REPO_ROOT = '/tmp'
MERGE_RE = /Merge pull request.*from (.*)\/(VFS-\d+\S*).*\s*/
GUI_CONFIG_RE = /^PRIMARY_IMAGE=.*(VFS-\d+\S*)'/

def open_file(path)
  if RbConfig::CONFIG['host_os'] =~ /mswin|mingw|cygwin/
    `start #{path}`
  elsif RbConfig::CONFIG['host_os'] =~ /darwin/
    `open #{path}`
  elsif RbConfig::CONFIG['host_os'] =~ /linux|bsd/
    `xdg-open #{path}`
  end
end

def repo_uri(project_type)
  "ssh://git@git.plgrid.pl:7999/vfs/#{project_type}.git"
end

def is_merge_commit(commit)
  commit.parents.count > 1 and commit.message =~ MERGE_RE
end

# returns a branch name without prefix, eg. VFS-9999-hello-world
def last_merge_branch(repo)
  merge_commit = repo.log.find {|c| is_merge_commit(c)}
  MERGE_RE.match(merge_commit.message)[2]
end

def current_gui(repo_path)
  gui_config = File.read(File.join(repo_path, 'gui-config.sh'))
  GUI_CONFIG_RE.match(gui_config)[1]
end

def repo_path(type)
  File.join(REPO_ROOT, type)
end
  
def get_repo(project_type, branch = 'develop')
  path = repo_path(project_type)
  if not File.exist?(path)
    Git.clone(repo_uri(project_type), project_type, path: REPO_ROOT)
  end
  git = Git.open(path)
  git.fetch
  git.checkout(branch)
  git.pull('origin', branch)
  git.reset_hard
  git
end

def change_gui(backend_type, gui_ref)
  path = File.join(repo_path(backend_type), 'gui-config.sh')
  new_content = File.open(path, 'r') do |gui_config|
    gui_config.read.gsub(/VFS-\d+\S*(?=')/, gui_ref)
  end
  File.open(path, 'w') do |gui_config|
    gui_config.write(new_content)
  end
end

def find_merge_commit(repo, version)
  version_regexp = Regexp.new version
  repo.log.find do |c|
    merge_match = MERGE_RE.match(c.message)
    c.parents.count > 1 and merge_match and version_regexp.match(merge_match[2])
  end
end

def gui_diff(gui_repo, used_gui, latest_gui)
  latest_merge = find_merge_commit(gui_repo, latest_gui)
  used_merge = find_merge_commit(gui_repo, used_gui)
  commits = gui_repo.log.between(used_merge.sha, latest_merge.sha)
  commits.select {|c| is_merge_commit(c)}
end

services = [
  {
    name: 'panel',
    gui: 'onepanel-gui',
    backend: 'onepanel',
  },
  {
    name: 'zone',
    gui: 'onezone-gui',
    backend: 'oz-worker',
  },
  {
    name: 'zone-old',
    gui: 'oz-gui-default',
    backend: 'oz-worker',
  },
  {
    name: 'provider',
    gui: 'op-gui-default',
    backend: 'op-worker',
  }
]

def publish_docker(type, version)
  short_name = "#{type}:#{version}"
  command = "
    docker pull docker.onedata.org/#{short_name} || exit $?
    docker tag docker.onedata.org/#{short_name} onedata/#{short_name} || exit $?
    docker push onedata/#{short_name} || exit $?
  "
  puts command
  %x(#{command})
  if $?.exitstatus != 0
    raise 'Docker commands failed!'
  end
end

def jira_link(issue)
  "https://jira.plgrid.pl/jira/browse/#{issue}"
end

def included_issues(commits)
  commits.map do |c|
    MERGE_RE.match(c.message)[2]
  end
end

def issues_str(issues)
  issues.reduce('') {|sum, msg| sum += "* #{msg}\n" }
end

def edit_message(message)
  tmp_path = "onedata-gui-commit-#{Process.pid}"
  File.open(tmp_path, 'w+') do |file|
    file.write(message)
  end
  open_file(tmp_path)
  puts 'Commit message editor opened, press ENTER when done'
  $stdin.gets
  begin
    file = File.open(tmp_path, 'r')
    new_message = file.read
  ensure
    file.close
    File.unlink(tmp_path)
    new_message
  end
end

chosen_services = ARGV.count > 2 ? ARGV[2..-1].map {|name| services.detect {|s| s[:name] == name } } : services
chosen_services.select! {|s| s != nil}
# eg. 'release/18.07.0-alpha'
target_backend_branch = ARGV[0] or 'develop'
source_frontend_branch = ARGV[1] or 'develop'

puts "Chosen services: #{chosen_services.map {|s| s[:name]} }"
puts "Target backend branch: #{target_backend_branch}"
puts "Source frontend branch: #{source_frontend_branch}"

chosen_services.each do |service|
  name = service[:name]
  gui = service[:gui]
  backend = service[:backend]
  gui_repo = get_repo(gui, source_frontend_branch)
  backend_repo = get_repo(backend, target_backend_branch)
  latest_gui = last_merge_branch(gui_repo)
  used_gui = current_gui(repo_path(backend))
  puts "#{name}: latest available GUI: #{latest_gui}, GUI used in backend: #{used_gui}"
  if latest_gui == used_gui
    puts '^ GUI versions the same - update not needed'
  else
    publish_docker(gui, latest_gui)
    issues_str =
      begin
        diff_commits = gui_diff(gui_repo, used_gui, latest_gui)
        issues = included_issues(diff_commits)
        issues.each {|i| puts jira_link(i) }
        ", including: #{issues.join(', ')}\n#{issues_str(issues)}"
      rescue Exception => error
        puts "Error making changelog: #{error}"
        puts "Backtrace:\n\t#{error.backtrace.join("\n\t")}"
        " to: #{latest_gui}"
      end
    commit_message = "Updating GUI#{issues_str}"
    puts commit_message
    commit_message = edit_message(commit_message)
    backend_new_branch = "feature/#{latest_gui}-update-gui-#{target_backend_branch.sub('/', '-')}"
    backend_repo.checkout(backend_new_branch, new_branch: true)
    change_gui(backend, latest_gui)
    backend_repo.add('gui-config.sh')
    backend_repo.commit(commit_message)
    backend_repo.push(remote = 'origin', branch = backend_new_branch)
  end
end
