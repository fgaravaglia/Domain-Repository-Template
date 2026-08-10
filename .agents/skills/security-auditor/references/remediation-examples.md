# Remediation Examples — Vulnerable → Fixed

Use these as templates for the "Fix" section of a finding. Adapt variable/table names to the real code —
never paste these verbatim into a report as if they were the user's code.

---

## A05 — Injection (SQL)

**Python (Flask/psycopg2) — vulnerable:**

```python
query = f"SELECT * FROM users WHERE email = '{email}'"
cur.execute(query)
```

**Fixed:**

```python
cur.execute("SELECT * FROM users WHERE email = %s", (email,))
```

**Node (Express/pg) — vulnerable:**

```js
const q = `SELECT * FROM users WHERE email = '${email}'`;
await client.query(q);
```

**Fixed:**

```js
await client.query('SELECT * FROM users WHERE email = $1', [email]);
```

**Java (Spring/JDBC) — vulnerable:**

```java
String sql = "SELECT * FROM users WHERE email = '" + email + "'";
stmt.executeQuery(sql);
```

**Fixed:**

```java
PreparedStatement ps = conn.prepareStatement("SELECT * FROM users WHERE email = ?");
ps.setString(1, email);
ps.executeQuery();
```

**PHP (PDO) — vulnerable:**

```php
$q = "SELECT * FROM users WHERE email = '$email'";
$pdo->query($q);
```

**Fixed:**

```php
$stmt = $pdo->prepare("SELECT * FROM users WHERE email = :email");
$stmt->execute(['email' => $email]);
```

**C# (ADO.NET) — vulnerable:**

```csharp
var cmd = new SqlCommand($"SELECT * FROM Users WHERE Email = '{email}'", conn);
```

**Fixed:**

```csharp
var cmd = new SqlCommand("SELECT * FROM Users WHERE Email = @Email", conn);
cmd.Parameters.AddWithValue("@Email", email);
```

---

## A05 — Injection (XSS)

**React — vulnerable:**

```jsx
<div dangerouslySetInnerHTML={{ __html: userComment }} />
```

**Fixed:**

```jsx
import DOMPurify from 'dompurify';
<div dangerouslySetInnerHTML={{ __html: DOMPurify.sanitize(userComment) }} />
// or, if no HTML is actually needed:
<div>{userComment}</div>
```

**Node (Express + plain templating) — vulnerable:**

```js
res.send(`<h1>Welcome ${req.query.name}</h1>`);
```

**Fixed:** use an auto-escaping template engine (EJS `<%= %>`, Handlebars `{{ }}`) instead of manual
string interpolation into HTML, and add a CSP header as defense-in-depth.

---

## A05 — Injection (Command)

**Python — vulnerable:**

```python
os.system(f"ping -c 1 {host}")
```

**Fixed:**

```python
subprocess.run(["ping", "-c", "1", host], check=True)  # no shell=True, args as a list
```

**Node — vulnerable:**

```js
exec(`convert ${filename} output.png`);
```

**Fixed:**

```js
execFile('convert', [filename, 'output.png']);
```

---

## A01 — Broken Access Control (IDOR)

**Vulnerable (any stack, pseudocode-adjacent Express example):**

```js
app.get('/invoices/:id', auth, async (req, res) => {
  const invoice = await Invoice.findById(req.params.id);
  res.json(invoice); // no ownership check
});
```

**Fixed:**

```js
app.get('/invoices/:id', auth, async (req, res) => {
  const invoice = await Invoice.findOne({ _id: req.params.id, ownerId: req.user.id });
  if (!invoice) return res.status(404).end(); // 404, not 403 — don't confirm existence to non-owners
  res.json(invoice);
});
```

## A01 — SSRF (now scored under Broken Access Control)

**Python (Flask) — vulnerable:**

```python
url = request.args.get('url')
resp = requests.get(url)  # fetches whatever the caller points at, including internal IPs
```

**Fixed:**

```python
from urllib.parse import urlparse
ALLOWED_HOSTS = {"api.trusted-partner.com"}
parsed = urlparse(url)
if parsed.hostname not in ALLOWED_HOSTS:
    abort(400)
resp = requests.get(url, timeout=3)
```

---

## A04 — Cryptographic Failures (password storage)

**Vulnerable (any language, conceptually):**

```python
password_hash = hashlib.md5(password.encode()).hexdigest()
```

**Fixed (Python, using a slow adaptive hash):**

```python
import bcrypt
password_hash = bcrypt.hashpw(password.encode(), bcrypt.gensalt())
# verification: bcrypt.checkpw(candidate.encode(), password_hash)
```

**Fixed (Node, using argon2):**

```js
const argon2 = require('argon2');
const hash = await argon2.hash(password);
```

**Fixed (Java, using Spring Security):**

```java
PasswordEncoder encoder = new BCryptPasswordEncoder();
String hash = encoder.encode(password);
```

---

## A07 — Authentication Failures (JWT handling)

**Node — vulnerable:**

```js
const decoded = jwt.decode(token); // no signature verification at all
```

**Fixed:**

```js
const decoded = jwt.verify(token, process.env.JWT_SECRET, { algorithms: ['HS256'] });
// explicit algorithm allow-list prevents "alg: none" / algorithm-confusion attacks
```

---

## A08 — Software or Data Integrity Failures (unsafe deserialization)

**Python — vulnerable:**

```python
data = pickle.loads(request.body)  # arbitrary code execution on untrusted input
```

**Fixed:**

```python
data = json.loads(request.body)
schema.validate(data)  # e.g. pydantic/marshmallow schema
```

**PHP — vulnerable:**

```php
$obj = unserialize($_POST['data']);
```

**Fixed:**

```php
$obj = json_decode($_POST['data'], true);
```

**Java — vulnerable:**

```java
ObjectInputStream ois = new ObjectInputStream(untrustedStream);
Object obj = ois.readObject();
```

**Fixed:** don't deserialize untrusted data with native Java serialization at all; use a JSON library
(Jackson) with a strict, allow-listed type mapping, or sign/HMAC the payload and verify before deserializing.

---

## A10 — Mishandling of Exceptional Conditions (fail-open)

**Vulnerable:**

```python
try:
    if not auth_service.check(token):
        raise Unauthorized()
except ServiceUnavailable:
    pass  # auth service is down -> silently let the request through
```

**Fixed:**

```python
try:
    if not auth_service.check(token):
        raise Unauthorized()
except ServiceUnavailable:
    raise ServiceUnavailable("Auth service down — denying by default")  # fail closed
```
