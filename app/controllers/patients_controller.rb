# frozen_string_literal: true

class PatientsController < ApplicationController
  def index
    @patients = Patient.order(:name)
    @patient = Patient.new
    @recent_summaries = Summary.order(created_at: :desc).limit(10)
  end

  def show
    @patient = Patient.find(params[:id])
    @document = Document.new
    @documents = @patient.documents.order(created_at: :desc)
    @summaries = @patient.summaries.order(created_at: :desc).limit(10)
    @summary = Summary.new
  end

  def create
    @patient = Patient.new(patient_params)
    if @patient.save
      redirect_to @patient, notice: "Patient created."
    else
      @patients = Patient.order(:name)
      @recent_summaries = Summary.order(created_at: :desc).limit(10)
      flash.now[:alert] = @patient.errors.full_messages.to_sentence
      render :index, status: :unprocessable_entity
    end
  end

  private

  def patient_params
    params.require(:patient).permit(:name, :mrn)
  end
end
