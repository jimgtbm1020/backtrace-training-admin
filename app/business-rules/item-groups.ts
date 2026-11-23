import {Assignment,Item} from './types';

export const itemTypes=['Tool','Dashboard','Smart Tool','Misc.'];

export function itemTypeColor(type:string):[number,number,number]{
 const colors:Record<string,[number,number,number]>={Tool:[21,59,112],Dashboard:[17,100,95],'Smart Tool':[102,61,136],'Misc.':[71,85,105]};
 return colors[type]||[71,85,105];
}

export function groupAgencyAssignments(agencyId:string,items:Item[],assignments:Assignment[]){
 const byId=new Map(items.map(item=>[item.id,item]));
 const rows=assignments.filter(assignment=>assignment.agency_id===agencyId).map(assignment=>({assignment,item:byId.get(assignment.item_id)}));
 const types=[...itemTypes,...Array.from(new Set(rows.map(row=>row.item?.item_type||'Unavailable item'))).filter(type=>!itemTypes.includes(type)).sort()];
 return types.map(type=>({type,rows:rows.filter(row=>(row.item?.item_type||'Unavailable item')===type).sort((a,b)=>(a.item?.name||'').localeCompare(b.item?.name||''))})).filter(group=>group.rows.length>0);
}
