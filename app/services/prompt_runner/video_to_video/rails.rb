module PromptRunner
  module VideoToVideo
    class Rails < Runner
      require "tempfile"
      require "fileutils"

      def run
        stitch_videos
      end

      private

      def stitch_videos
        puts "Starting video stitching process"

        # Get all video files from previous prompt runs
        video_attachments = get_video_attachments

        if video_attachments.empty?
          fail_with_error("No video files found from previous prompt runs")
          return
        end

        puts "Found #{video_attachments.count} video files to stitch"

        begin
          # Create temporary directory for processing
          temp_dir = create_temp_directory

          # Download videos to temporary files
          video_files = download_videos_to_temp_files(video_attachments, temp_dir)

          # Create ffmpeg concat file
          concat_file = create_concat_file(video_files, temp_dir)

          # Run ffmpeg to stitch videos
          output_file = stitch_with_ffmpeg(concat_file, temp_dir)

          # Attach the stitched video to the prompt run
          attach_stitched_video(output_file)

          # Update with success
          prompt_run.update!(
            response: {
              body: {
                message: "Successfully stitched #{video_attachments.count} videos",
                input_count: video_attachments.count,
                output_filename: File.basename(output_file)
              },
              status: "completed",
              error: nil
            }
          )
          prompt_run.update_with_status!("completed")

        rescue => e
          ::Rails.logger.error("Video stitching failed: #{e.message}")
          ::Rails.logger.error("Backtrace: #{e.backtrace.join("\n")}")
          fail_with_error("Video stitching failed: #{e.message}")
        ensure
          # Clean up temporary files
          cleanup_temp_files(temp_dir) if temp_dir
        end
      end

      def get_video_attachments
        # Get all completed prompt runs from the same run, excluding the current one
        completed_prompt_runs = prompt_run.run.prompt_runs
                                          .where(status: "completed")
                                          .where.not(id: prompt_run.id)
                                          .includes(attachments_attachments: :blob)

        video_attachments = []

        completed_prompt_runs.each do |pr|
          pr.attachments.each do |attachment|
            if attachment.blob.content_type&.start_with?("video/")
              video_attachments << attachment
            end
          end
        end

        # Sort by created_at to maintain order
        video_attachments.sort_by(&:created_at)
      end

      def create_temp_directory
        temp_dir = File.join(::Rails.root, "tmp", "video_stitching_#{SecureRandom.hex(8)}")
        FileUtils.mkdir_p(temp_dir)
        temp_dir
      end

      def download_videos_to_temp_files(video_attachments, temp_dir)
        video_files = []

        video_attachments.each_with_index do |attachment, index|
          # Determine file extension from content type
          extension = case attachment.blob.content_type
          when "video/mp4"
            ".mp4"
          when "video/avi"
            ".avi"
          when "video/mov", "video/quicktime"
            ".mov"
          when "video/webm"
            ".webm"
          else
            ".mp4" # Default fallback
          end

          temp_filename = File.join(temp_dir, "video_#{index.to_s.rjust(3, '0')}#{extension}")

          # Download the attachment to the temporary file
          attachment.blob.open do |file|
            FileUtils.cp(file.path, temp_filename)
          end

          video_files << temp_filename
          puts "Downloaded video #{index + 1}/#{video_attachments.count}: #{File.basename(temp_filename)}"
        end

        video_files
      end

      def create_concat_file(video_files, temp_dir)
        concat_filename = File.join(temp_dir, "concat_list.txt")

        File.open(concat_filename, "w") do |file|
          video_files.each do |video_file|
            # Use absolute paths and escape single quotes for ffmpeg
            escaped_path = video_file.gsub("'", "'\"'\"'")
            file.puts "file '#{escaped_path}'"
          end
        end

        puts "Created concat file with #{video_files.count} entries"
        concat_filename
      end

      def stitch_with_ffmpeg(concat_file, temp_dir)
        output_filename = File.join(temp_dir, "stitched_video_#{Time.current.to_i}.mp4")

        # Build ffmpeg command
        # -f concat: use concat demuxer
        # -safe 0: allow unsafe file paths
        # -i: input concat file
        # -c copy: copy streams without re-encoding (faster)
        # -y: overwrite output file if it exists
        cmd = [
          "ffmpeg",
          "-f", "concat",
          "-safe", "0",
          "-i", concat_file,
          "-c", "copy",
          "-y",
          output_filename
        ]

        puts "Running ffmpeg command: #{cmd.join(' ')}"

        # Execute the command and capture output
        result = system(*cmd)

        unless result
          raise "ffmpeg command failed with exit status #{$?.exitstatus}"
        end

        unless File.exist?(output_filename)
          raise "Output file was not created: #{output_filename}"
        end

        file_size = File.size(output_filename)
        puts "Successfully created stitched video: #{File.basename(output_filename)} (#{file_size} bytes)"

        output_filename
      end

      def attach_stitched_video(output_file)
        filename = "stitched_video_#{Time.current.to_i}.mp4"

        File.open(output_file, "rb") do |file|
          prompt_run.attachments.attach(
            io: file,
            filename: filename,
            content_type: "video/mp4"
          )
        end

        puts "Attached stitched video: #{filename}"
      end

      def cleanup_temp_files(temp_dir)
        return unless temp_dir && Dir.exist?(temp_dir)

        begin
          FileUtils.rm_rf(temp_dir)
          puts "Cleaned up temporary directory: #{temp_dir}"
        rescue => e
          ::Rails.logger.warn("Failed to clean up temporary directory #{temp_dir}: #{e.message}")
        end
      end

      def fail_with_error(message, response_data = nil)
        puts "Error: #{message}"
        prompt_run.update!(
          response: {
            body: response_data || { error: message },
            status: "failed",
            error: message
          }
        )
        prompt_run.update_with_status!("failed")
      end
    end
  end
end
