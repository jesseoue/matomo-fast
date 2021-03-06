terraform {
  required_version = ">= 0.12"
}

provider "digitalocean" {
  token = var.do_token
}

data "template_file" "install_script" {
  template = file("./scripts/install-docker.sh")
  vars = {
    domain = var.domain
  }
}

data "digitalocean_ssh_key" "key" {
  name = var.ssh_key_name
}

resource "digitalocean_droplet" "matomo_server" {
  image              = "ubuntu-20-04-x64"
  name               = "matomo-server"
  region             = var.region
  size               = var.droplet_image
  private_networking = true
  user_data          = format("%s", data.template_file.install_script.rendered)
  ssh_keys           = [data.digitalocean_ssh_key.key.id]
}

resource "digitalocean_floating_ip" "matomo_floating_ip" {
  droplet_id = digitalocean_droplet.matomo_server.id
  region     = digitalocean_droplet.matomo_server.region
}

resource "digitalocean_domain" "matomo_domain" {
  name = var.domain
}

resource "digitalocean_record" "matomo_record" {
  domain = digitalocean_domain.matomo_domain.name
  type   = "A"
  name   = var.domain_record
  value  = digitalocean_floating_ip.matomo_floating_ip.ip_address
}

resource "digitalocean_firewall" "matomo_fw" {
  name = "matomo-fw"

  droplet_ids = [digitalocean_droplet.matomo_server.id]

  inbound_rule {
    protocol         = "tcp"
    port_range       = "22"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  inbound_rule {
    protocol         = "tcp"
    port_range       = "80"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  inbound_rule {
    protocol         = "tcp"
    port_range       = "443"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  inbound_rule {
    protocol         = "icmp"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  inbound_rule {
    protocol         = "udp"
    port_range       = "10000"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "tcp"
    port_range            = "53"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "udp"
    port_range            = "53"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "icmp"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "udp"
    port_range            = "10000"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "tcp"
    port_range            = "80"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "tcp"
    port_range            = "443"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
}
