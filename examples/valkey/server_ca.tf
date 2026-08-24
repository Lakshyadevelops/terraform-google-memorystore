/**
 * Copyright 2024 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

resource "google_privateca_ca_pool" "ca_pool_region_west" {
  provider = google-beta

  project  = var.project_id
  name     = "ca-pool-us-west1-${random_string.key_suffix.result}"
  location = "us-west1"
  tier     = "ENTERPRISE"

  depends_on = [module.enable_apis]
}

resource "google_privateca_ca_pool_iam_member" "memorystore_sa_ca_iam" {
  provider = google-beta

  ca_pool = google_privateca_ca_pool.ca_pool_region_west.id
  role    = "roles/privateca.certificateRequester"
  member  = "serviceAccount:${google_project_service_identity.memorystore_sa.email}"

  depends_on = [time_sleep.wait_for_memorystore_sa_ready_state]
}

resource "google_privateca_certificate_authority" "ca_west_authority" {
  provider = google-beta
  project  = var.project_id

  pool                     = google_privateca_ca_pool.ca_pool_region_west.name
  certificate_authority_id = "ca-auth-us-west1-${random_string.key_suffix.result}"
  location                 = "us-west1"

  config {
    subject_config {
      subject {
        organization = "Test Org"
        common_name  = "test-ca"
      }
    }
    x509_config {
      ca_options {
        is_ca = true
      }
      key_usage {
        base_key_usage {
          cert_sign = true
          crl_sign  = true
        }
        extended_key_usage {
          server_auth = true
        }
      }
    }
  }

  key_spec {
    algorithm = "RSA_PKCS1_4096_SHA256"
  }

  deletion_protection                    = false
  ignore_active_certificates_on_deletion = true
  skip_grace_period                      = true

  depends_on = [module.enable_apis]
}

resource "time_sleep" "wait_for_ca_pool_iam_propagation" {
  create_duration = "120s"
  depends_on      = [google_privateca_ca_pool_iam_member.memorystore_sa_ca_iam]
}
