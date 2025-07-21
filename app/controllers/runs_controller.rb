class RunsController < ApplicationController
  skip_before_action :verify_authenticity_token, if: :json_request?
  allow_unauthenticated_access only: %i[ create show ]
  before_action :set_run, only: %i[ show edit update destroy ]
  layout "authenticated"

  # GET /runs or /runs.json
  def index
    per_page = 5  # Adjust this number based on your needs
    @runs = Run.order(id: :desc)
              .limit(per_page + 1)
              .where("id < ?", params[:after] || 1000000000000000000)

    @has_more = @runs.size > per_page
    @runs = @runs.first(per_page) if @has_more
  end

  # GET /runs/1 or /runs/1.json
  def show
  end

  # GET /runs/new
  def new
    @run = Run.new
  end

  # GET /runs/1/edit
  def edit
  end

  # POST /runs or /runs.json
  def create
    @run = Run.new(run_params)

    if @run.save
      if @run.conversation_id.present?
        redirect_to conversation_path(@run.conversation)
      else
        redirect_to @run
      end
    else
      # Handle errors
      render :new
    end
  end

  # PATCH/PUT /runs/1 or /runs/1.json
  def update
    respond_to do |format|
      if @run.update(run_params)
        format.html { redirect_to @run, notice: "Run was successfully updated." }
        format.json { render :show, status: :ok, location: @run }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @run.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /runs/1 or /runs/1.json
  def destroy
    @run.destroy!

    respond_to do |format|
      format.html { redirect_to runs_path, status: :see_other, notice: "Run was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private

    # Use callbacks to share common setup or constraints between actions.
    def set_run
      @run = Run.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def run_params
      params.require(:run).permit(:flow_id, :message, :subject_image, :background_reference, :conversation_id, :webhook_url, :input_image_url, :variables_string, variables: {}, attachment_urls: [], attachments: [])
    end

    def json_request?
      request.format.json?
    end
end
