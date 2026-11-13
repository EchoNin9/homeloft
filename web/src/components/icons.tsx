import {
  mdiCalendarClock, mdiCheckboxMarkedCircle, mdiDocker, mdiDoorClosed, mdiDoorOpen, mdiEye, mdiFan, mdiFanOff, mdiFlash,
  mdiGarage, mdiGarageOpen, mdiLightbulb, mdiLightbulbOutline, mdiMotionSensor, mdiMotionSensorOff, mdiPackage, mdiPackageUp,
  mdiPalette, mdiRadioboxBlank, mdiSmoke, mdiThermometer, mdiThermostat, mdiToggleSwitchVariant, mdiToggleSwitchVariantOff,
  mdiWaterAlert, mdiWaterPercent, mdiWeatherNight, mdiWhiteBalanceSunny, mdiWindowClosed, mdiWindowOpen, mdiWindowShutter,
  mdiWindowShutterOpen,
} from '@mdi/js';
import type { Entity } from '../client';
import { domainOf } from './util';

/** One Material Design icon (the set Home Assistant uses). Decorative unless `label` is given. */
export function Icon({ path, label, size = 24 }: { path: string; label?: string; size?: number }) {
  return (
    <svg viewBox="0 0 24 24" width={size} height={size} className="hl-icon" role={label ? 'img' : undefined} aria-label={label} aria-hidden={label ? undefined : true}>
      <path d={path} fill="currentColor" />
    </svg>
  );
}

/** The Homeloft mark: a gabled house with a loft window and a bird heading out (outbound-only messages).
 *  Same drawing as cloud/terraform/modules/homeloft/branding/*.svg. */
export function HomeloftMark({ size = 24 }: { size?: number }) {
  return (
    <svg viewBox="0 0 24 24" width={size} height={size} className="hl-icon" aria-hidden="true">
      <path d="M12 3.6L20.4 10.6V21H14.2V15.6H9.8V21H3.6V10.6Z M12 8.6a1.7 1.7 0 1 0 0.001 0Z" fill="currentColor" fillRule="evenodd" />
      <path d="M16.1 2.9q1.4 0.1 2.5 1.6q1.1-1.5 2.5-1.6" fill="none" stroke="currentColor" strokeWidth="1.2" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  );
}

/** HA `icon` attribute values we can draw; anything else falls back to the domain icon. */
const NAMED: Record<string, string> = { 'mdi:docker': mdiDocker, 'mdi:flash': mdiFlash, 'mdi:thermometer': mdiThermometer };

const BINARY: Record<string, [on: string, off: string]> = {
  door: [mdiDoorOpen, mdiDoorClosed],
  garage_door: [mdiGarageOpen, mdiGarage],
  window: [mdiWindowOpen, mdiWindowClosed],
  opening: [mdiDoorOpen, mdiDoorClosed],
  motion: [mdiMotionSensor, mdiMotionSensorOff],
  occupancy: [mdiMotionSensor, mdiMotionSensorOff],
  moisture: [mdiWaterAlert, mdiWaterPercent],
  smoke: [mdiSmoke, mdiSmoke],
};

const SENSOR: Record<string, string> = { temperature: mdiThermometer, humidity: mdiWaterPercent, power: mdiFlash, energy: mdiFlash };

// ponytail: a hand-picked map, not HA's full icon rules. Add entries as new entity kinds show up.
export function entityIcon(e: Entity): string {
  const a = e.attributes;
  if (typeof a.icon === 'string' && NAMED[a.icon]) return NAMED[a.icon]!;
  const on = e.state === 'on';
  const dc = String(a.device_class ?? '');
  switch (domainOf(e.entity_id)) {
    case 'light': return on ? mdiLightbulb : mdiLightbulbOutline;
    case 'switch': return on ? mdiToggleSwitchVariant : mdiToggleSwitchVariantOff;
    case 'fan': return on ? mdiFan : mdiFanOff;
    case 'climate': return mdiThermostat;
    case 'cover': return dc === 'garage' ? (e.state === 'closed' ? mdiGarage : mdiGarageOpen) : e.state === 'closed' ? mdiWindowShutter : mdiWindowShutterOpen;
    case 'scene': return mdiPalette;
    case 'binary_sensor': return (BINARY[dc] ?? [mdiCheckboxMarkedCircle, mdiRadioboxBlank])[on ? 0 : 1];
    case 'sensor': return SENSOR[dc] ?? (e.entity_id.startsWith('sensor.docker_') ? mdiDocker : /temperature/.test(e.entity_id) ? mdiThermometer : mdiEye);
    case 'update': return on ? mdiPackageUp : mdiPackage;
    case 'sun': return e.state === 'above_horizon' ? mdiWhiteBalanceSunny : mdiWeatherNight;
    default: return mdiCalendarClock;
  }
}

/**
 * Which colour the icon wears, as HA does: 'on' (amber) for lights/switches that are on, 'alert'
 * (red) for an open door or a stopped service, 'active' (accent) for other active states, '' for idle.
 */
export function iconTone(e: Entity): '' | 'on' | 'alert' | 'active' {
  const d = domainOf(e.entity_id);
  const s = e.state;
  if (s === 'unavailable' || s === 'unknown') return '';
  if (d === 'light' || d === 'switch' || d === 'fan') return s === 'on' ? 'on' : '';
  if (d === 'binary_sensor') return s !== 'on' ? '' : ['door', 'garage_door', 'window', 'opening', 'moisture', 'smoke', 'problem'].includes(String(e.attributes.device_class)) ? 'alert' : 'active';
  if (e.entity_id.startsWith('sensor.docker_')) return s === 'running' && e.attributes.health !== 'unhealthy' ? 'active' : 'alert';
  if (d === 'update') return s === 'on' ? 'on' : '';
  if (d === 'sun') return s === 'above_horizon' ? 'on' : '';
  if (d === 'climate') return s !== 'off' ? 'on' : '';
  if (d === 'cover') return s !== 'closed' ? 'active' : '';
  if (d === 'sensor') return 'active';
  return '';
}
