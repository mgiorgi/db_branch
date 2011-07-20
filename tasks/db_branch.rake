namespace :db do
  namespace :branch do
  
    desc "Saves a db dump for the current git branch"
    task :save => :environment do
      branch = current_git_branch
      puts "Saving db dump: branch=#{branch}, environment=#{RAILS_ENV} ..."
      dump_database_for_branch(branch)
      puts "Done."
    end
  
    desc "Restores a db dump for the current git branch"
    task :restore => :environment do
      branch = current_git_branch
      puts "Restoring db dump: branch=#{branch}, environment=#{RAILS_ENV} ..."
      restore_database_for_branch(branch)
      puts "Done."
    end
  
    desc "Lists all branch-specific db dumps"
    task :list => :environment do
      list_files("#{RAILS_ROOT}/tmp/branch-dumps")
    end
  
  end
end

def current_git_branch
  matches = `git branch`.match /^\* ([^(]\S+)$/
  branch = matches && matches[1]
  branch || fatal_error!("Current git branch not found!")
end

def branch_dump_pathname(branch)
  Pathname("#{RAILS_ROOT}/tmp/branch-dumps/#{branch}-#{RAILS_ENV}.sql")
end

def list_files(path, prefix = '')
  dir = Pathname(path)
  dir.children.each do |c|
    if File::directory?(c.to_s)
      new_prefix = prefix.present? ? "#{prefix}/#{c.basename.to_s}" : c.basename.to_s
      list_files(c.to_s, new_prefix)
    else
      puts "#{(prefix+'/') if prefix.present?}#{c.basename}"
    end
  end if dir.exist?
end

def dump_database_for_branch(branch)
  config = current_db_config
  pathname = branch_dump_pathname(branch)
  pathname.dirname.mkpath
  dump_cmd = "/usr/bin/env mysqldump --skip-add-locks -u#{config['username']}"
  dump_cmd << " -p'#{config['password']}'" unless config['password'].blank?
  dump_cmd << " #{config['database']} > #{pathname}"
  system(dump_cmd)
end

def restore_database_for_branch(branch)
  config = current_db_config
  pathname = branch_dump_pathname(branch)
  fatal_error!("No db dump exists for current branch!") unless pathname.exist?
  auth_credentials = "-u#{config['username']}"
  auth_credentials << " -p'#{config['password']}'" unless config['password'].blank?
  drop_cmd = "mysqladmin -f #{auth_credentials} drop #{config['database']}"
  create_cmd = "mysqladmin -f #{auth_credentials} create #{config['database']}"
  restore_cmd = "/usr/bin/env mysql #{auth_credentials} #{config['database']} < #{pathname}"
  system(drop_cmd)
  puts "Command being executed: #{drop_cmd}"
  system(create_cmd)
  puts "Command being executed: #{create_cmd}"
  system(restore_cmd)
  puts "Command being executed: #{restore_cmd}"
end

def current_db_config
  ActiveRecord::Base.configurations[RAILS_ENV]
end

def fatal_error!(msg)
  puts("[ERR] #{msg}"); exit!
end
