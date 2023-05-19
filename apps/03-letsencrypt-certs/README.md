__Create the RH SSO client secret__

Create a file named aws-credentials.yaml with the following

~~~
apiVersion: v1
kind: Secret
metadata:
  name: cloud-dns-credentials
  namespace: letsencrypt-job
type: Opaque 
stringData: 
  AWS_ACCESS_KEY_ID: "YOUR_ACCESS_ID"
  AWS_SECRET_ACCESS_KEY: "YOUR_ACCESS_KEY_"
  AWS_DNS_SLOWRATE: "1"
  EAB_KID: YOUR_ZERO_SSL_ID 
  EAB_HMAC_Key: YOUR_ZERO_SSL_KEY
~~~

Then seal the secret

`kubeseal --cert ~/.bitnami/tls.crt --format yaml < aws-credentials.yaml > 05-sealed-aws-credentials.yaml`
