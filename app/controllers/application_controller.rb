class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  def index
    @layout_data = TheKnotLayout::Data.new({
                                               title: 'Wedding Registry & Bridal Registries - The Knot',
                                               description: 'Get tips and trends in wedding registries. Find the top shops to set up your wedding registry and more. Browse through different bridal registries and set up a registry today.'
                                           })
    @xo_metadata = XO::Metadata::Builder.new(application_name: 'Registry')
    @hub = true
    @isLoggedIn = current_member
    gon.ENV = gon_env

    if @isLoggedIn.present?
      @userId = member_id
      response = Api::RegistryApi.get_couples_summary_by_user_id(@userId)
      if response.present?
        @coupleId = response["CoupleId"]
        @coupleRegistries = {
            registries:process_registries(response["CoupleRegistries"]),
            registries_len:response["NumberOfCoupleRegistries"],
            stats: {
                total: response["NumberOfProducts"],
                fulfilled: response["NumberOfProducts"] - response["NumberOfUnfulfilledProducts"]
            }
        }
        @charity = response["UserCharity"]
      end
    end
  end
end
