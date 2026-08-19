import React, { useState } from 'react';
import { gql } from '@apollo/client';
import { useMutation } from '@apollo/client/react';

const CREAR_EMPRESA = gql`
  mutation CrearEmpresa($nombre: String!, $logo_url: String) {
    crearEmpresa(nombre: $nombre, logo_url: $logo_url) {
      id
      nombre
      logo_url
      activo
    }
  }
`;

const RegistroEmpresa = () => {
  const [nombre, setNombre] = useState('');
  const [archivo, setArchivo] = useState(null);
  const [cargando, setCargando] = useState(false);

  const [crearEmpresa] = useMutation(CREAR_EMPRESA);

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!nombre.trim()) return alert('El nombre es obligatorio');

    setCargando(true);
    try {
      let logoUrl = null;

      // Paso 1: Subir el archivo de logo al servidor REST
      if (archivo) {
        const formData = new FormData();
        formData.append('logo', archivo);

        const response = await fetch('/api/upload-logo', {
          method: 'POST',
          body: formData,
        });

        const data = await response.json();
        if (!data.success) throw new Error(data.message || 'Error al subir el logo');
        logoUrl = data.logoUrl;
      }

      // Paso 2: Crear la empresa mediante GraphQL
      const { data } = await crearEmpresa({
        variables: {
          nombre,
          logo_url: logoUrl,
        },
      });

      alert(`Empresa "${data.crearEmpresa.nombre}" creada con éxito.`);
      setNombre('');
      setArchivo(null);
    } catch (error) {
      console.error('Error al registrar empresa:', error);
      alert(error.message);
    } finally {
      setCargando(false);
    }
  };

  return (
    <div style={{ maxWidth: '400px', margin: '2rem auto', fontFamily: 'sans-serif' }}>
      <h2>Registrar Nueva Empresa</h2>
      <form onSubmit={handleSubmit}>
        <div style={{ marginBottom: '1rem' }}>
          <label style={{ display: 'block', marginBottom: '0.5rem' }}>Nombre de la Empresa:</label>
          <input
            type="text"
            value={nombre}
            onChange={(e) => setNombre(e.target.value)}
            style={{ width: '100%', padding: '8px', boxSizing: 'border-box' }}
            required
          />
        </div>

        <div style={{ marginBottom: '1rem' }}>
          <label style={{ display: 'block', marginBottom: '0.5rem' }}>Logo de la Empresa:</label>
          <input
            type="file"
            accept="image/*"
            onChange={(e) => setArchivo(e.target.files[0])}
            style={{ width: '100%' }}
          />
        </div>

        <button type="submit" disabled={cargando} style={{ padding: '10px 20px', cursor: 'pointer' }}>
          {cargando ? 'Guardando...' : 'Crear Empresa'}
        </button>
      </form>
    </div>
  );
};

export default RegistroEmpresa;