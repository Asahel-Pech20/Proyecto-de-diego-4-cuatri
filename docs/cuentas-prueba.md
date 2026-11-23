# Cuentas de prueba (solo desarrollo local)

| Uso | Correo | Contraseña |
|---|---|---|
| Probar la app en el emulador | `emulador@utm.test` | `prueba1234` |
| **Presentación / demo** | `demo@utm.test` | `demo1234` |

Existen solo en la base local de Docker. No usar contraseñas reales aquí.

## Cuenta de demo

Se crea o se deja limpia con:

```powershell
cd backend
npm run seed:demo
```

Deja 5 materias con horario de lunes a viernes, 5 tareas y exámenes en los próximos días hábiles,
Programación Móvil con 3 de 5 faltas y el simulador en "necesitas 8.75".

Se puede correr después de cada ensayo: conserva el mismo usuario y marca los datos anteriores
como borrados, así que el teléfono se limpia solo con **sincronizar** (no hace falta cerrar sesión).
Las fechas se calculan desde el día en que se corre: córrelo el mismo día de la presentación.

Para cambiar materias, horario o tareas, edita las listas al inicio de `backend/scripts/seed-demo.js`.
