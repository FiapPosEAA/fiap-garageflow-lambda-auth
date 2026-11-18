const jwt = require('jsonwebtoken');
const sql = require('mssql');

const normalizeCpf = (cpf = '') => String(cpf).replace(/\D/g, '');

const isValidCpf = (cpf) => {
  const normalized = normalizeCpf(cpf);

  if (!normalized || normalized.length !== 11) return false;
  if (new Set(normalized).size === 1) return false;

  const digits = normalized.split('').map(Number);

  const calculateVerifierDigit = (sliceLength, weightStart) => {
    let sum = 0;
    for (let i = 0; i < sliceLength; i++) {
      sum += digits[i] * (weightStart - i);
    }
    const mod = sum % 11;
    return mod < 2 ? 0 : 11 - mod;
  };

  const firstDigit = calculateVerifierDigit(9, 10);
  const secondDigit = calculateVerifierDigit(10, 11);

  return digits[9] === firstDigit && digits[10] === secondDigit;
};

exports.handler = async (event) => {
  try {
    const payload = typeof event.body === 'string' ? JSON.parse(event.body) : event;
    const cpf = normalizeCpf(payload.cpf || payload.document);
    if (!isValidCpf(cpf)) {
      return {
        statusCode: 401,
        body: JSON.stringify({ error: 'CPF inválido.' })
      };
    }

    const pool = await sql.connect({
      server: process.env.DB_HOST,
      port: Number(process.env.DB_PORT || 1433),
      database: process.env.DB_NAME,
      user: process.env.DB_USER,
      password: process.env.DB_PASSWORD,
      connectionTimeout: 60000,
      requestTimeout: 60000,
      options: {
        encrypt: process.env.DB_ENCRYPT !== 'false',
        trustServerCertificate: process.env.DB_TRUST_SERVER_CERTIFICATE === 'true'
      }
    });
    const result = await pool.request()
      .input('document', sql.VarChar(20), cpf)
      .query('SELECT TOP 1 Id AS id, Name AS name, Document AS document, IsActive AS isActive FROM Customers WHERE Document = @document');
    await pool.close();
    if (result.recordset.length === 0) {
      return {
        statusCode: 401,
        body: JSON.stringify({ error: 'Cliente não encontrado.' })
      };
    }

    const customer = result.recordset[0];
    if (customer.isActive === false) {
      return {
        statusCode: 401,
        body: JSON.stringify({ error: 'Cliente inativo.' })
      };
    }

    const token = jwt.sign(
      {
        sub: customer.id,
        name: customer.name,
        document: customer.document,
        role: 'Customer'
      },
      process.env.JWT_SECRET || 'dev-secret',
      {
        expiresIn: '8h',
        issuer: process.env.JWT_ISSUER || 'GarageFlowService',
        audience: process.env.JWT_AUDIENCE || 'GarageFlowServiceClients'
      }
    );

    return {
      statusCode: 200,
      body: JSON.stringify({
        token: `Bearer ${token}`,
        expiresAt: new Date(Date.now() + 8 * 60 * 60 * 1000).toISOString(),
        customer: {
          id: customer.id,
          name: customer.name,
          document: customer.document
        }
      })
    };
  } catch (error) {
    console.error(error);
    return {
      statusCode: 500,
      body: JSON.stringify({ error: 'Erro interno na autenticação.' })
    };
  }
};
