# K8s TLS secrets update

Works only with Nginx ingress controller

### Preparation of certificates

Put private key content into `cert/tls.key` file

```
-----BEGIN RSA PRIVATE KEY-----
...
-----END RSA PRIVATE KEY-----
```

Combining several certificates into one single `cert/tls.crt` chain file (sequence is important)

> Guide - https://www.digicert.com/kb/ssl-support/pem-ssl-creation.htm

```
-----BEGIN CERTIFICATE-----
...
-----END CERTIFICATE-----
-----BEGIN CERTIFICATE-----
...
-----END CERTIFICATE-----
...
```

### Run script

```shell
$ ./replace.sh
```

If you want to exclude one or multiple tls secrets then just simply edit `excludeTls` value

```ini
# Editable variable
excludeTls="loki-proxy-tls, grafana-tls" # tls1, tls2,..
```

Check all tls secrets in your cluster

```shell
$ kubectl get secret -A --field-selector type=kubernetes.io/tls
```