#!/usr/bin/env ruby

require 'git'
require 'tempfile'

REPO_ROOT = '/tmp'
MERGE_RE = /Merge pull request.*from (.*)\/(VFS-\d+).*\s*/
GUI_CONFIG_RE = /^PRIMARY_IMAGE=.*(VFS-\d+)/

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
  
def get_repo(project_type, branch = nil)
  path = repo_path(project_type)
  if not File.exist?(path)
    Git.clone(repo_uri(project_type), project_type, path: REPO_ROOT)
  end
  git = Git.open(path)
  git.fetch
  git.checkout((branch or 'develop'))
  git.pull
  git.reset_hard
  git
end

def change_gui(backend_type, gui_ref)
  path = File.join(repo_path(backend_type), 'gui-config.sh')
  File.open(path, 'r+') do |gui_config|
    new_content = gui_config.read.gsub(/VFS-\d+/, gui_ref)
    gui_config.rewind
    gui_config.write(new_content)
  end
end

def find_merge_commit(repo, version)
  repo.log.find do |c|
    merge_match = MERGE_RE.match(c.message)
    c.parents.count > 1 and merge_match and merge_match[2] == version
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
    docker pull docker.onedata.org/#{short_name}
    docker tag docker.onedata.org/#{short_name} onedata/#{short_name}
    docker push onedata/#{short_name}
  "
  puts command
  %x(#{command})
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
  gets
  begin
    file = File.open(tmp_path, 'r')
    new_message = file.read
  ensure
    file.close
    File.unlink(tmp_path)
    new_message
  end
end

chosen_services = ARGV.count > 0 ? ARGV.map {|name| services.detect {|s| s[:name] == name } } : services
chosen_services.select! {|s| s != nil}

puts "Chosen services: #{chosen_services.map {|s| s[:name]} }"

chosen_services.each do |service|
  name = service[:name]
  gui = service[:gui]
  backend = service[:backend]
  gui_repo = get_repo(gui)
  backend_repo = get_repo(backend)
  latest_gui = last_merge_branch(gui_repo)
  used_gui = current_gui(repo_path(backend))
  puts "#{name}: latest GUI #{latest_gui}, GUI used #{used_gui}"
  if latest_gui == used_gui
    puts '^ GUI versions the same - update not needed'
  else
    publish_docker(gui, latest_gui)
    diff_commits = gui_diff(gui_repo, used_gui, latest_gui)
    issues = included_issues(diff_commits)
    commit_message = "Updating GUI, including: #{issues.join(', ')}\n#{issues_str(issues)}"
    puts commit_message
    issues.each {|i| puts jira_link(i) }
    commit_message = edit_message(commit_message)
    backend_repo.checkout("feature/#{latest_gui}-update-gui", new_branch: true)
    change_gui(backend, latest_gui)
    backend_repo.add('gui-config.sh')
    backend_repo.commit(commit_message)
    backend_repo.push
  end
end
