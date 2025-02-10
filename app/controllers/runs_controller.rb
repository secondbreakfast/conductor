class RunsController < ApplicationController
  before_action :set_cors_headers
  allow_unauthenticated_access only: %i[ create show ]
  before_action :set_run, only: %i[ show edit update destroy ]

  # GET /runs or /runs.json
  def index
    @runs = Run.all
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

    respond_to do |format|
      if @run.save
        format.html { redirect_to @run, notice: "Run was successfully created." }
        format.json { render :show, status: :created, location: @run }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @run.errors, status: :unprocessable_entity }
      end
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
    def set_cors_headers
      headers["Access-Control-Allow-Origin"] = "*"
      headers["Access-Control-Allow-Methods"] = "GET, POST, PUT, PATCH, DELETE, OPTIONS"
      headers["Access-Control-Allow-Headers"] = "Origin, Content-Type, Accept, Authorization, Token"
    end

    # Use callbacks to share common setup or constraints between actions.
    def set_run
      @run = Run.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def run_params
      params.require(:run).permit(:flow_id, :status, :started_at, :completed_at, :subject_image, :background_reference, attachments: [])
    end
end
