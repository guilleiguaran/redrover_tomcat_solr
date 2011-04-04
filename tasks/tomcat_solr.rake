namespace :tomcat do
  namespace :solr do

    desc "Start local Tomcat Solr on localhost:8080"
    task :start => [:status, :multicore_init] do 
      unless @running
        Rake::Task["tomcat:solr:solr_instance"].invoke
        exec("bash", "-c", "#{ENV["CATALINA_HOME"]}/bin/catalina.sh start")
      end
    end

    desc "Stop local Tomcat Solr"
    task :stop => :status do 
      if @running
        exec("bash", "-c", "#{ENV["CATALINA_HOME"]}/bin/catalina.sh stop")
      end
    end

    task :restart => [:stop, :start]

    task :kill do
      exec("kill -9 $(ps aux | grep java | grep tomcat | grep -v grep | awk '{print $2;}')")
    end

    desc "Ensure Java environment variables"
    task :java_env do
      raise "Must have JAVA_HOME defined\nUse: export=JAVA_HOME=/path/to/java/jre" unless ENV["JAVA_HOME"].present?
      ENV["CATALINA_HOME"] ||= File.expand_path(File.join(File.dirname(__FILE__), '..', 'tomcat'))
    end

    desc "Build dynamic solr instance"
    task :solr_instance do
      solr_home = Rails.root.join('solr')
      solr_war = solr_home.join('lib', 'apache-solr.war')
      file = File.new("#{ENV["CATALINA_HOME"]}/conf/Catalina/localhost/solr.xml", "w")
      xml = Builder::XmlMarkup.new(:target => file, :indent => 2)
      xml.instruct!
      xml.Context(:docBase => solr_war, :debug => "0", :crossContext => "true") do
        xml.Environment(:name => "solr/home", "type" => "java.lang.String", "value" => solr_home, "override"  => "true")
      end
      file.close
    end

    desc "Check the processes compared to the pid"
    task :status => :java_env do
      pid_file = Dir.glob(File.join(ENV["CATALINA_HOME"], "temp", "**", "*[0-9]*"))
      @running = if pid_file.present?
        if `ps -ef | grep #{pid_file[0][/(\d+)$/]} | grep tomcat | grep -v grep`.present? 
          puts "Tomcat is running"
          true
        else
          puts "Found pid #{pid_file}, but process is not running"
          puts "Removing stale pid file"
          File.delete(pid_file.first)
          false
        end
      else
        puts "Tomcat is not running"
        false
      end
    end

    desc "Symlinks solr.xml into solr home to enable MultiCore"
    task :multicore_init do
      solr_xml_src = Rails.root.join('lib', 'tomcat_solr', 'solr', 'solr.xml')
      solr_xml_dest = Rails.root.join('solr', 'solr.xml')
      unless File.exists?(solr_xml_dest)
        File.symlink(solr_xml_src, solr_xml_dest) 
      end
    end
  end
end
