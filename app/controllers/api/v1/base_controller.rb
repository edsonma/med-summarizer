# frozen_string_literal: true

module Api
  module V1
    class BaseController < ActionController::API
      rescue_from ActiveRecord::RecordNotFound do |e|
        render json: { error: e.message }, status: :not_found
      end

      rescue_from ActiveRecord::RecordInvalid do |e|
        render json: { error: e.record.errors.full_messages }, status: :unprocessable_entity
      end
    end
  end
end
