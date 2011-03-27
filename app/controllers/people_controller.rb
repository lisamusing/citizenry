class PeopleController < InheritedResources::Base
  respond_to :html, :xml, :json

  include Localness
  before_filter :authenticate_user!, :only => [:new, :create]
  before_filter :require_owner_or_admin!, :only => [:edit, :update, :destroy]
  before_filter :pick_photo_input, :only => [:update, :create]
  before_filter :set_user_id_if_admin, :only => [:update, :create]

  def index
    @view = :grid if params[:grid]
    @people ||= Person.all.shuffle

    super
  end

  def tag
    @tag = params[:tag]
    @people = Person.tagged_with(@tag)

    render :action => :index
  end

  def show
    @person = Person.includes(:companies, :groups, :projects).find(params[:id])

    super
  end

  def new
    if params[:q].present? && params[:authentications].present?
      query = params[:q]
      authentications = params[:authentications].keys

      @found_people = []
      current_user.authentications.find(authentications).each do |auth|
        if auth.api_client
          @found_people += auth.api_client.search(query)
          if auth.provider == 'twitter'
            @rate_limit_status = auth.api_client.client.rate_limit_status
          end
        end
      end

      @found_people.sort! {|a,b| localness(b) <=> localness(a)}
      @found_people = Person.all(:conditions => ['name LIKE ?', "%#{query}%"]) + @found_people

    end

    super
  end

  def create
    if params[:form_context] == 'add_self'
      @person = Person.new(params[:person])
      @person.user = current_user
      @person.imported_from_provider = current_user.authentications.first.provider
      @person.imported_from_id = current_user.authentications.first.uid
    end

    super
  end

  def claim
    if @person.user.present?
      flash[:error] = "This person has already been claimed."
      redirect_to(:action => 'show') and return
    end
  end

  def photo
  end

  private

  def require_owner_or_admin!
    authenticate_user! and return unless current_user

    unless current_user.admin? || current_user == resource.user
      flash[:warning] = "You aren't allowed to edit this person."
      redirect_to person_path(@person)
    end
  end

  def pick_photo_input
    params.delete(:photo_import_label) if params[:photo].present?
  end

  def set_user_id_if_admin
    if current_user.admin? && params[:person] && params[:person][:user_id].present?
      resource.user_id = params[:person][:user_id]
    end
  end
end
