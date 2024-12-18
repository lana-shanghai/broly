import { useState, useEffect } from "react";
import { NavLink } from "react-router";
import InscriptionView from "../components/inscription/View";
import InscriptionForm from "../components/inscription/Form";
import InscriptionStatus from "../components/inscription/Status";
import { Pagination } from "../components/Pagination";
import { getNewInscriptions } from "../api/inscriptions";

function Home() {
  const [isInscribing, setIsInscribing] = useState(false);

  const defaultInscription: any[] = [];
  const [recentInscriptions, setRecentInscriptions] = useState(defaultInscription);
  const [recentsPagination, setRecentsPagination] = useState({
    pageLength: 16,
    page: 1
  });

  useEffect(() => {
    const fetchInscriptions = async () => {
      let result = await getNewInscriptions(recentsPagination.pageLength, recentsPagination.page);
      if (result.data) {
        if (recentsPagination.page === 1) {
          setRecentInscriptions(result.data);
        } else {
          const newInscriptions = result.data.filter((inscription: any) => {
            return !recentInscriptions.some((recent: any) => recent.id === inscription.id);
          });
          setRecentInscriptions([...recentInscriptions, ...newInscriptions]);
        }
      }
    }
    try {
      fetchInscriptions();
    } catch (error) {
      console.error(error);
    }
  }, [recentsPagination]);

  return (
    <div className="w-full flex flex-col h-max">
      <div className="bg__color--tertiary w-full flex flex-col items-center justify-center py-8">
        <h1 className="text-4xl font-bold">Inscribe on Bitcoin</h1>
        <h2 className="text-lg mb-8">Starknet's Decentralized Inscriptor Network</h2>
        <InscriptionForm isInscribing={isInscribing} setIsInscribing={setIsInscribing} />
        {isInscribing && <InscriptionStatus />}
      </div>
      <div className="w-full flex flex-col items-center py-2 bg__color--primary h-full border-t-2 border-[var(--color-primary-light)]">
        <div className="w-full flex flex-row items-center justify-between">
          <h1 className="text-xl font-bold px-4">Recent Inscriptions</h1>
          <NavLink to="/inscriptions" className="flex flex-row items-center">
            <p className="text-sm font-bold px-4 tab__nav">Explore &rarr;</p>
          </NavLink>
        </div>
        <div className="w-full grid grid-cols-4 gap-4 px-4 py-8">
          {recentInscriptions.map((inscription) => (
            <InscriptionView key={inscription.id} inscription={inscription} />
          ))}
        </div>
        <Pagination
          data={recentInscriptions}
          setState={setRecentsPagination}
          stateValue={recentsPagination}
        />
      </div>
    </div>
  );
}

export default Home;
