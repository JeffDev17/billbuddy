class NavigationSessionService
  def initialize(session)
    @session = session
  end

  def store_return_path(referer_path, default_fallback = nil)
    # Clean and validate the referer path
    if referer_path.present? && valid_return_path?(referer_path)
      @session[:return_path] = extract_path_from_url(referer_path)
      @session[:return_fallback] = default_fallback
    end
  end

  def determine_return_path(default_path)
    stored_path = @session[:return_path]
    fallback_path = @session[:return_fallback] || default_path

    # Clear the stored path after using it
    clear_return_path

    # Return stored path if valid, otherwise use fallback
    if stored_path.present? && valid_return_path?(stored_path)
      stored_path
    else
      fallback_path
    end
  end

  def smart_return_path_for_action(referer, default_path)
    # For actions like mark_completed, mark_cancelled, etc.
    # Uses referer if valid, otherwise default
    if referer.present? && valid_return_path?(referer)
      extract_path_from_url(referer)
    else
      default_path
    end
  end

  def clear_return_path
    @session.delete(:return_path)
    @session.delete(:return_fallback)
  end

  # Store multiple return paths for complex navigation
  def store_named_return_path(name, path, fallback = nil)
    @session["#{name}_return_path"] = extract_path_from_url(path) if path.present?
    @session["#{name}_return_fallback"] = fallback if fallback.present?
  end

  def get_named_return_path(name, default_path)
    stored_path = @session["#{name}_return_path"]
    fallback_path = @session["#{name}_return_fallback"] || default_path

    # Clear after use
    @session.delete("#{name}_return_path")
    @session.delete("#{name}_return_fallback")

    if stored_path.present? && valid_return_path?(stored_path)
      stored_path
    else
      fallback_path
    end
  end

  private

  def extract_path_from_url(url)
    return url unless url.include?("://")

    begin
      uri = URI.parse(url)
      path = uri.path
      path += "?#{uri.query}" if uri.query.present?
      path += "##{uri.fragment}" if uri.fragment.present?
      path
    rescue URI::InvalidURIError
      url
    end
  end

  def valid_return_path?(path)
    return false if path.blank?

    # Extract just the path part if it's a full URL
    path_only = extract_path_from_url(path)

    # Security: Only allow internal paths
    return false if path_only.include?("://")

    # Prevent infinite redirect loops
    excluded_patterns = [
      "/users/sign_in",
      "/users/sign_up",
      "/users/sign_out",
      "/users/password"
      # Add other auth/admin paths as needed
    ]

    excluded_patterns.none? { |pattern| path_only.include?(pattern) }
  end
end
