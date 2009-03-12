require 'osx/foundation'

# Some code borrowed from http://rails.aizatto.com/2007/11/28/taming-the-autotest-beast-with-fsevents/
class Listener
  
  def initialize(valid_extensions = nil, &block)
    @valid_extensions = valid_extensions
    timestamp_checked
    
    begin
      callback = lambda do |stream, ctx, num_events, paths, marks, event_ids|
        changed_files = extract_changed_files_from_paths(split_paths(paths, num_events))        
        timestamp_checked
        yield changed_files
      end

      OSX.require_framework '/System/Library/Frameworks/CoreServices.framework/Frameworks/CarbonCore.framework'
      stream = OSX::FSEventStreamCreate(OSX::KCFAllocatorDefault, callback, nil, [Dir.pwd], OSX::KFSEventStreamEventIdSinceNow, 0.5, 0)
      unless stream
        puts "Failed to create stream"
        exit
      end

      OSX::FSEventStreamScheduleWithRunLoop(stream, OSX::CFRunLoopGetCurrent(), OSX::KCFRunLoopDefaultMode)
      unless OSX::FSEventStreamStart(stream)
        puts "Failed to start stream"
        exit 
      end

      OSX::CFRunLoopRun()
    rescue Interrupt
      OSX::FSEventStreamStop(stream)
      OSX::FSEventStreamInvalidate(stream)
      OSX::FSEventStreamRelease(stream)
    end
  end
  
  def timestamp_checked
    @last_check = Time.now
  end
  
  def split_paths(paths, num_events)
    paths.regard_as('*')
    rpaths = []        
    num_events.times { |i| rpaths << paths[i] }
    rpaths    
  end
  
  def extract_changed_files_from_paths(paths)
    changed_files = []
    paths.each do |path|
      next if ignore_path?(path)
      Dir.glob(path + "*").each do |file|
        next if ignore_file?(file)
        changed_files << file if file_changed?(file)
      end
    end
    changed_files
  end
  
  def file_changed?(file)
    File.stat(file).mtime > @last_check
  end
  
  def ignore_path?(path)
    path =~ /(?:^|\/)\.(git|svn)/
  end
  
  def ignore_file?(file)
    File.basename(file).index('.') == 0 or not valid_extension?(file)
  end
  
  def file_extension(file)
    file =~ /\.(\w+)$/ and $1
  end
  
  def valid_extension?(file)
    @valid_extensions.nil? or @valid_extensions.include?(file_extension(file))
  end
  
end