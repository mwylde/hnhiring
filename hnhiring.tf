provider "google" {
  project = "micahw-com"
  region = "us-central1-a"
}

resource "google_storage_bucket" "www-hnhiring-me" {
  name     = "www.hnhiring.me"
  storage_class = "MULTI_REGIONAL"

  website {
    main_page_suffix = "index.html"
  }
}
