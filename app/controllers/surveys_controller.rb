class SurveysController < ApplicationController
  before_filter :authenticate_user!
  before_filter :find_event
  before_filter :find_rsvp, except: :index
  before_filter :validate_user!, except: :index
  before_filter :validate_organizer!, only: :index

  def new
    @survey = Survey.where(rsvp_id: @rsvp.id).first_or_initialize

    if @survey.persisted?
      flash[:error] = "It looks like you've already taken this survey! Email workshops@railsbridge.org with any other feedback you have."
    end
  end

  def create
    @survey = Survey.new(survey_params)
    @survey.rsvp_id = params[:rsvp_id]

    if @survey.save
      flash[:notice] = "Thanks for taking the survey!"
      redirect_to root_path
    else
      render :new
    end
  end

  def index
    @student_surveys = Survey.where(rsvp_id: @event.rsvps.where(role_id: Role::STUDENT.id).pluck(:id))
    @volunteer_surveys = Survey.where(rsvp_id: @event.volunteer_rsvps.pluck(:id))
  end

  private

  def survey_params
    params.require(:survey).permit(Survey::PERMITTED_ATTRIBUTES)
  end

  def find_event
    @event = Event.find(params[:event_id])
  end

  def find_rsvp
    @rsvp = Rsvp.find(params[:rsvp_id])
  end

  def validate_user!
    unless current_user.rsvps.include?(@rsvp)
      redirect_to root_path, notice: "You're not allowed to do that. Here, look at some events instead!"
    end
  end
end
