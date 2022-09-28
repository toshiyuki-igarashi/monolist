# Refer to https://www.autovice.jp/articles/146

# Railsアプリのルート
rails_root = File.expand_path('../../', __FILE__)

# Gemfileの場所
ENV['BUNDLE_GEMFILE'] = rails_root + "/Gemfile"

# Unicornの設定
worker_processes  2
timeout           15
working_directory rails_root
pid               File.expand_path 'tmp/pids/unicorn.pid', rails_root
listen            File.expand_path 'tmp/sockets/.unicorn.sock', rails_root
stdout_path       File.expand_path 'log/unicorn.log', rails_root
stderr_path       File.expand_path 'log/unicorn.log', rails_root
preload_app       true

# フォークが行われる前の処理
before_fork do |server, worker|
  defined?(ActiveRecord::Base) and ActiveRecord::Base.connection.disconnect!
  old_pid = "#{server.config[:pid]}.oldbin"
  if old_pid != server.pid
    begin
      Process.kill "QUIT", File.read(old_pid).to_i
    rescue Errno::ENOENT, Errno::ESRCH
    end
  end
end

# フォークが行われた後の処理
after_fork do |server, worker|
  defined?(ActiveRecord::Base) and ActiveRecord::Base.establish_connection
end

# フォークが行われる前の処理
before_fork do |server, worker|
  defined?(ActiveRecord::Base) and ActiveRecord::Base.connection.disconnect!
end

# フォークが行われた後の処理
after_fork do |server, worker|
  defined?(ActiveRecord::Base) and ActiveRecord::Base.establish_connection
end

# フォークが行われる前の処理
before_fork do |server, worker|
  old_pid = "#{server.config[:pid]}.oldbin"
  if old_pid != server.pid
    begin
      Process.kill "QUIT", File.read(old_pid).to_i
    rescue Errno::ENOENT, Errno::ESRCH
    end
  end
end
