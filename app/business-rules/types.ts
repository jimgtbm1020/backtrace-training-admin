export type Agency={id:string;agency_name:string;agency_address:string|null;city_state_zip:string|null;agency_city:string|null;agency_state:string|null;agency_zip:string|null;active:boolean;updated_at:string};
export type Item={id:string;name:string;item_type:string;description:string;expected_outcome:string;updated_at:string};
export type Assignment={id:string;agency_id:string;item_id:string;data_source:string;retention_value:number;retention_unit:string;updated_at:string};
export const agencyLocation=(agency:Agency)=>[agency.agency_city,agency.agency_state,agency.agency_zip].filter(Boolean).join(', ')||agency.city_state_zip||'';
export const agencyAddress=(agency:Agency)=>[agency.agency_address,agencyLocation(agency)].filter(Boolean).join(', ');
