- The footer must be printed in orange (`\e[38;5;208m`) and match this shape:
  ```
  ==== RESULTS ====
  <fields>
  ==== END RESULTS ====
  ```
- Allowed fields: `KubeContext`, `Namespace`, `Deployments`, `Services`, `Ingresses`, `Pods`, `Health checks`, `Samples`.
- No extra text; print in orange (ANSI 38;5;208).
