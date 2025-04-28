class ConversationsController < ApplicationController
  before_action :set_conversation, only: [ :show ]
  layout "authenticated"

  def index
    @conversations = Conversation.all.order(created_at: :desc)
  end

  def show
    @run = @conversation.runs.new
    @flows = Flow.all
  end

  def new
    @conversation = Conversation.new
  end

  def create
    @conversation = Conversation.new(conversation_params)

    if @conversation.save
      redirect_to @conversation, notice: "Conversation was successfully created."
    else
      render :new
    end
  end

  private

  def set_conversation
    @conversation = Conversation.find(params[:id])
  end

  def conversation_params
    params.require(:conversation).permit(:title)
  end
end
