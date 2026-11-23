# TestFlight delivery. Requires an App Store Connect API key (see README → Release).
default_platform(:ios)

platform :ios do
  desc "Build the Beta configuration and upload to TestFlight"
  lane :beta do
    sh("cd .. && node admin/validate.mjs && node admin/build-bundle.mjs")
    sh("cd .. && xcodegen generate")
    app_store_connect_api_key(
      key_id: ENV.fetch("ASC_KEY_ID"),
      issuer_id: ENV.fetch("ASC_ISSUER_ID"),
      key_content: ENV.fetch("ASC_KEY_CONTENT"),
      is_key_content_base64: true
    )
    increment_build_number(build_number: latest_testflight_build_number + 1, xcodeproj: "Culture.xcodeproj")
    build_app(project: "Culture.xcodeproj", scheme: "Culture", configuration: "Beta", export_method: "app-store")
    upload_to_testflight(skip_waiting_for_build_processing: true)
  end
end
