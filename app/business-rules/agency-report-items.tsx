import CatalogContent from './catalog-content';
import {groupAgencyAssignments} from './item-groups';
import {formatRetention} from './types';
import styles from './rules.module.css';

export default function AgencyReportItems({groups}:{groups:ReturnType<typeof groupAgencyAssignments>}){
 return <>{groups.map((group,index)=><section key={group.type} className={styles.catalogSection} data-item-type={group.type} aria-labelledby={'report-type-'+index}>
  <header className={styles.catalogHeader}><h3 id={'report-type-'+index}>{group.type}</h3><span className={styles.catalogCount}>{group.rows.length} {group.rows.length===1?'item':'items'}</span></header>
  <div className={styles.reportItems}>{group.rows.map(({assignment,item})=><article className={styles.savedItemCard} key={assignment.id}>
   <header className={styles.savedItemHeader}><div><span className={styles.itemTypeTag}>{item?.item_type||group.type}</span><h4 className={styles.catalogItemName}>{item?.name||'Unavailable item'}</h4></div></header>
   <dl className={styles.reportMetadata}>
    <div><dt>Data source</dt><dd>{assignment.data_source||'Not specified'}</dd></div>
    <div><dt>Retention</dt><dd>{formatRetention(assignment)}</dd></div>
   </dl>
   <dl className={styles.savedItemDetails}>
    <div><dt><span aria-hidden="true" className={styles.detailMarker}/>Description</dt><dd><CatalogContent text={item?.description||'Not specified'}/></dd></div>
    <div className={styles.expectedOutcome}><dt><span aria-hidden="true" className={styles.detailMarker}/>Expected outcome</dt><dd><CatalogContent text={item?.expected_outcome||'Not specified'}/></dd></div>
   </dl>
  </article>)}</div>
 </section>)}</>;
}
