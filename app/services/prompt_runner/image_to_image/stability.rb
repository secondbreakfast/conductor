module PromptRunner
  module ImageToImage
    class Stability < Runner
      def run
        case prompt.selected_model
        when "replace_background_and_relight"
          replace_background_and_relight
        end
      end

      def replace_background_and_relight
        params = {}
        # Only add params if they're present
        params[:background_prompt] = prompt.background_prompt if prompt.background_prompt.present?
        params[:background_reference] = background_reference if background_reference.present?
        params[:foreground_prompt] = prompt.foreground_prompt if prompt.foreground_prompt.present?
        params[:negative_prompt] = prompt.negative_prompt if prompt.negative_prompt.present?
        params[:preserve_original_subject] = prompt.preserve_original_subject unless prompt.preserve_original_subject.nil?
        params[:original_background_depth] = prompt.original_background_depth unless prompt.original_background_depth.nil?
        params[:keep_original_background] = prompt.keep_original_background unless prompt.keep_original_background.nil?
        params[:seed] = prompt.seed if prompt.seed.present?
        params[:output_format] = prompt.output_format if prompt.output_format.present?

        result = ::Stability::ApiWrapper.new.replace_background_and_relight(subject_image, **params)
        if result.present?
          prompt_run.update!(
            response: {
              body: result.parsed_response,
              status: result.code,
              error: result.success? ? nil : result.body
            }
          )
        end
        if result.success?
          PollRunJob.set(wait: 5.seconds).perform_later(prompt_run)
        else
          prompt_run.update_with_status!("failed")
        end
      end

      def subject_image
        if prompt_run.run.subject_image.attached?
          prompt_run.run.subject_image
        elsif prompt.subject_image.attached?
          prompt.subject_image
        else
          nil
        end
      end

      def background_reference
        if prompt_run.run.background_reference.attached?
          prompt_run.run.background_reference
        elsif prompt.background_reference.attached?
          prompt.background_reference
        else
          nil
        end
      end
    end
  end
end
